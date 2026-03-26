import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../app/theme.dart';
import '../models/file_transfer_model.dart';
import '../services/webrtc_service.dart';

class FileShareScreen extends StatefulWidget {
  final WebRTCService webrtc;
  const FileShareScreen({super.key, required this.webrtc});

  @override
  State<FileShareScreen> createState() => _FileShareScreenState();
}

class _FileShareScreenState extends State<FileShareScreen> {
  bool _sending = false;
  double _sendProgress = 0;
  String? _sendingFile;

  // ✅ Store received files with bytes for inline preview
  final List<Map<String, dynamic>> _receivedFiles = [];
  FileTransfer? _activeReceive;

  Function(String)? _prevOnFileStart;
  Function(Uint8List)? _prevOnFileChunk;
  Function(String)? _prevOnFileEnd;

  static const Set<String> _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic'
  };
  static const Set<String> _videoExts = {'mp4', 'mov', 'avi', 'mkv', '3gp'};

  @override
  void initState() {
    super.initState();
    _setupReceiver();
  }

  void _setupReceiver() {
    _prevOnFileStart = widget.webrtc.onFileStart;
    _prevOnFileChunk = widget.webrtc.onFileChunk;
    _prevOnFileEnd = widget.webrtc.onFileEnd;

    widget.webrtc.onFileStart = (header) {
      final parts = header.replaceFirst('FILE_START:', '').split(':');
      final fileName = parts[0];
      final totalSize = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      if (!mounted) return;
      setState(() {
        _activeReceive = FileTransfer(fileName: fileName, totalSize: totalSize);
        _activeReceive!.status = TransferStatus.inProgress;
      });
    };

    widget.webrtc.onFileChunk = (chunk) {
      if (_activeReceive == null || !mounted) return;
      _activeReceive!.buffer.addAll(chunk);
      _activeReceive!.receivedBytes += chunk.length;
      setState(() {});
    };

    widget.webrtc.onFileEnd = (fileName) async {
      if (_activeReceive == null) return;
      try {
        final dir = await getExternalStorageDirectory();
        final file = File('${dir!.path}/$fileName');
        final bytes = Uint8List.fromList(_activeReceive!.buffer);
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        setState(() {
          _receivedFiles.add({
            'name': fileName,
            'path': file.path,
            'size': bytes.length,
            'bytes': bytes, // ✅ keep bytes in memory for preview
          });
          _activeReceive = null;
        });
      } catch (e) {
        debugPrint('❌ File save failed: $e');
      }
    };
  }

  @override
  void dispose() {
    widget.webrtc.onFileStart = _prevOnFileStart;
    widget.webrtc.onFileChunk = _prevOnFileChunk;
    widget.webrtc.onFileEnd = _prevOnFileEnd;
    super.dispose();
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    await _sendBytes(file.bytes!, file.name);
  }

  // ✅ Camera: take photo and send directly
  Future<void> _takePhotoAndSend() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final name = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _sendBytes(bytes, name);
  }

  // ✅ Camera: record video and send
  Future<void> _takeVideoAndSend() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final name = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _sendBytes(bytes, name);
  }

  Future<void> _sendBytes(Uint8List bytes, String fileName) async {
    setState(() {
      _sending = true;
      _sendingFile = fileName;
      _sendProgress = 0;
    });

    final total = bytes.length;
    const chunkSize = 16384;
    widget.webrtc.sendText('FILE_START:$fileName:$total');

    int sent = 0;
    for (int i = 0; i < bytes.length; i += chunkSize) {
      if (!mounted) break;
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      widget.webrtc.sendBinaryChunk(bytes.sublist(i, end));
      sent += (end - i);
      setState(() => _sendProgress = sent / total);
      await Future.delayed(const Duration(milliseconds: 15));
    }

    widget.webrtc.sendText('FILE_END:$fileName');
    if (mounted) {
      setState(() {
        _sending = false;
        _sendingFile = null;
      });
    }
  }

  bool _isImage(String name) =>
      _imageExts.contains(name.split('.').last.toLowerCase());
  bool _isVideo(String name) =>
      _videoExts.contains(name.split('.').last.toLowerCase());

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFile(String path) => OpenFilex.open(path);

  void _viewFullImage(BuildContext context, Uint8List bytes, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(name,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(child: Image.memory(bytes)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GhostTheme.bg,
      appBar: AppBar(
        backgroundColor: GhostTheme.surface,
        title: const Text('File Share',
            style: TextStyle(color: GhostTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GhostTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Send controls ──────────────────────────────────────────
            if (_sending) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GhostTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GhostTheme.accent),
                ),
                child: Column(children: [
                  Text('Sending: $_sendingFile',
                      style: const TextStyle(
                          color: GhostTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _sendProgress,
                      backgroundColor: GhostTheme.border,
                      color: GhostTheme.accent,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(_sendProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: GhostTheme.accent, fontSize: 12)),
                ]),
              ),
            ] else ...[
              // ✅ Three send options
              Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.attach_file,
                      label: 'Pick File',
                      color: GhostTheme.accent,
                      onTap: _pickAndSendFile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.camera_alt,
                      label: 'Take Photo',
                      color: GhostTheme.green,
                      onTap: _takePhotoAndSend,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.videocam,
                      label: 'Record Video',
                      color: Colors.blue,
                      onTap: _takeVideoAndSend,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ── Active incoming transfer ────────────────────────────────
            if (_activeReceive != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GhostTheme.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GhostTheme.accent),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📥 ${_activeReceive!.fileName}',
                          style:
                              const TextStyle(color: GhostTheme.textPrimary)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _activeReceive!.progress,
                        backgroundColor: GhostTheme.border,
                        color: GhostTheme.green,
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatSize(_activeReceive!.receivedBytes)} / ${_formatSize(_activeReceive!.totalSize)}',
                        style: const TextStyle(
                            color: GhostTheme.textSecondary, fontSize: 11),
                      ),
                    ]),
              ),
              const SizedBox(height: 12),
            ],

            // ── Received files grid/list ────────────────────────────────
            if (_receivedFiles.isNotEmpty) ...[
              const Text('Received',
                  style: TextStyle(
                      color: GhostTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _receivedFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final f = _receivedFiles[i];
                    final name = f['name'] as String;
                    final path = f['path'] as String;
                    final size = f['size'] as int;
                    final bytes = f['bytes'] as Uint8List?;

                    if (_isImage(name) && bytes != null) {
                      // ✅ Image preview card
                      return GestureDetector(
                        onTap: () => _viewFullImage(ctx, bytes, name),
                        child: Container(
                          decoration: BoxDecoration(
                            color: GhostTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GhostTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: Image.memory(
                                  bytes,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(children: [
                                  const Icon(Icons.image,
                                      color: GhostTheme.green, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(
                                                color: GhostTheme.textPrimary,
                                                fontSize: 12),
                                            overflow: TextOverflow.ellipsis),
                                        Text(_formatSize(size),
                                            style: const TextStyle(
                                                color: GhostTheme.textSecondary,
                                                fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.fullscreen,
                                      color: GhostTheme.textSecondary,
                                      size: 18),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else if (_isVideo(name)) {
                      // ✅ Video card with tap to open
                      return GestureDetector(
                        onTap: () => _openFile(path),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GhostTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GhostTheme.border),
                          ),
                          child: Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.play_circle_fill,
                                  color: Colors.blue, size: 32),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: GhostTheme.textPrimary,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis),
                                    Text(_formatSize(size),
                                        style: const TextStyle(
                                            color: GhostTheme.textSecondary,
                                            fontSize: 11)),
                                    const Text('Tap to play',
                                        style: TextStyle(
                                            color: Colors.blue, fontSize: 10)),
                                  ]),
                            ),
                          ]),
                        ),
                      );
                    } else {
                      // ✅ Generic file card
                      return GestureDetector(
                        onTap: () => _openFile(path),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: GhostTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GhostTheme.border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.insert_drive_file,
                                color: GhostTheme.green, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: GhostTheme.textPrimary)),
                                    Text(_formatSize(size),
                                        style: const TextStyle(
                                            color: GhostTheme.textSecondary,
                                            fontSize: 11)),
                                    const Text('Tap to open',
                                        style: TextStyle(
                                            color: GhostTheme.accent,
                                            fontSize: 10)),
                                  ]),
                            ),
                            const Icon(Icons.open_in_new,
                                color: GhostTheme.textSecondary, size: 18),
                          ]),
                        ),
                      );
                    }
                  },
                ),
              ),
            ] else if (_activeReceive == null) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open,
                          color:
                              GhostTheme.textSecondary.withValues(alpha: 0.4),
                          size: 64),
                      const SizedBox(height: 12),
                      const Text('No files yet',
                          style: TextStyle(
                              color: GhostTheme.textHint, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Send or receive files to see them here',
                          style: TextStyle(
                              color: GhostTheme.textHint, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ✅ Reusable action button
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
