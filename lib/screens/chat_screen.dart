import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../app/theme.dart';
import '../models/message_model.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/overlay_service.dart';
import '../widgets/message_bubble.dart';
import 'call_screen.dart';
import 'file_share_screen.dart';
import 'screen_share_screen.dart'; // BUG 6 FIX: import the screen share screen
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String myId;
  const ChatScreen({super.key, required this.roomId, required this.myId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late SignalingService _signaling;
  late WebRTCService _webrtc;

  final List<ChatMessage> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<int> _incomingFileBuffer = [];

  bool _peerConnected = false;
  bool _dataChannelOpen = false;
  bool _isFilePickerOpen = false;
  // BUG 7 FIX: track whether the "calling..." dialog is currently on screen
  bool _callingDialogShowing = false;
  String _statusText = 'Connecting to server...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionsAndInit();
  }

  Future<void> _requestPermissionsAndInit() async {
    await [Permission.camera, Permission.microphone].request();
    _initConnection();
  }

  Future<void> _initConnection() async {
    _signaling = SignalingService(roomId: widget.roomId, userId: widget.myId);
    _webrtc = WebRTCService(signaling: _signaling);

    _webrtc.onTextMessage = (text) {
      if (text.startsWith('FILE_START:') ||
          text.startsWith('FILE_END:') ||
          text.isEmpty) {
        return;
      }
      _addMessage(text, isMe: false);
    };

    _webrtc.onFileStart = (header) {
      final parts = header.replaceFirst('FILE_START:', '').split(':');
      _incomingFileBuffer.clear();
      _addSystemMessage('📎 Receiving file: ${parts[0]}...');
    };

    _webrtc.onFileChunk = (chunk) {
      _incomingFileBuffer.addAll(chunk);
    };

    _webrtc.onFileEnd = (rawFileName) async {
      // BUG 14 FIX: strip any path traversal from the received filename
      final fileName = _sanitizeFileName(rawFileName);
      try {
        final dir = await getExternalStorageDirectory();
        if (dir == null) {
          _incomingFileBuffer.clear();
          _addSystemMessage('✅ File received: $fileName');
          return;
        }
        final filePath = '${dir.path}/$fileName';
        final bytes = Uint8List.fromList(_incomingFileBuffer);
        await File(filePath).writeAsBytes(bytes);
        _incomingFileBuffer.clear();

        final ext = fileName.split('.').last.toLowerCase();
        const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
        if (imageExts.contains(ext) && mounted) {
          setState(() => _messages.add(ChatMessage(
                id: const Uuid().v4(),
                text: fileName,
                isMe: false,
                timestamp: DateTime.now(),
                type: ChatMessageType.image,
                imagePath: filePath,
              )));
          _scrollToBottom();
        } else {
          _addSystemMessage('✅ File received: $fileName');
        }
      } catch (e) {
        _incomingFileBuffer.clear();
        _addSystemMessage('✅ File received: $fileName');
      }
    };

    // BUG 3 FIX: Use data channel callbacks (not peer connection state) to drive _dataChannelOpen
    _webrtc.onDataChannelOpen = () {
      if (!mounted) return;
      setState(() {
        _dataChannelOpen = true;
        _statusText = 'Peer connected 🟢';
      });
      _addSystemMessage('🔒 Secure P2P connection established');
    };

    _webrtc.onDataChannelClosed = () {
      if (!mounted) return;
      setState(() {
        _dataChannelOpen = false;
      });
    };

    // Keep peer connection state for disconnect detection only
    _webrtc.onConnectionStateChange = _buildConnectionStateHandler();

    _signaling.onPeerJoined = () async {
      if (!mounted) return;
      setState(() {
        _peerConnected = true;
        _statusText = 'Peer joined — connecting...';
      });
      try {
        await _webrtc.createOffer();
      } catch (e) {
        debugPrint('❌ createOffer (onPeerJoined) failed: $e');
        _addSystemMessage('❌ Connection failed. Try rejoining.');
      }
    };

    _signaling.onPeerAlready = () async {
      if (!mounted) return;
      setState(() {
        _peerConnected = true;
        _statusText = 'Peer found — waiting for secure link...';
      });
      _addSystemMessage('👤 Peer found. Establishing secure channel...');
    };

    _signaling.onPeerLeft = () {
      if (!mounted) return;
      setState(() {
        _peerConnected = false;
        _dataChannelOpen = false;
        _statusText = 'Peer left the room';
      });
      _addSystemMessage('👻 Peer has left. Messages clearing...');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _messages.clear());
      });
    };

    _signaling.onError = (err) {
      if (!mounted) return;
      setState(
          () => _statusText = '⏳ Server waking up... please wait (up to 30s)');
      _addSystemMessage('⏳ $err — Render free server may be starting up.');
    };

    _signaling.onIncomingCall = (isVideo) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(isVideo ? Icons.videocam : Icons.call,
                  color: Colors.green, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              isVideo ? '📹 Incoming Video Call' : '📞 Incoming Audio Call',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Your peer is calling...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              // ❌ Reject
              GestureDetector(
                onTap: () {
                  _signaling.sendCallReject();
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red),
                  ),
                  child:
                      const Icon(Icons.call_end, color: Colors.red, size: 28),
                ),
              ),
              // ✅ Accept — receiver does NOT send offer (isCaller: false)
              GestureDetector(
                onTap: () {
                  // FIX ONE-WAY AUDIO: Do NOT send call-accept here. Let CallScreen 
                  // send it AFTER media tracks are added to the peer connection.
                  Navigator.pop(ctx);
                  // BUG 11 FIX: re-wire onConnectionStateChange after returning from call (receiver side)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        isVideo: isVideo,
                        isCaller: false,
                        existingWebRTC: _webrtc,
                        existingSignaling: _signaling,
                      ),
                    ),
                  ).then((_) {
                    if (!mounted) return;
                    _webrtc.onConnectionStateChange =
                        _buildConnectionStateHandler();
                  });
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Icon(Icons.call, color: Colors.green, size: 28),
                ),
              ),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      );
    };

    try {
      await _webrtc.initialize(audio: false, video: false);
    } catch (e) {
      debugPrint('❌ WebRTC init failed: $e');
    }

    if (!mounted) return;
    setState(() => _statusText = 'Waiting for peer to join...');
    _signaling.connect();
  }

  /// BUG 3 + BUG 11 FIX: shared handler factory so both caller and receiver
  /// can re-wire the same logic after returning from CallScreen.
  Function(RTCPeerConnectionState) _buildConnectionStateHandler() {
    return (state) {
      final s = state.toString();
      if (s.contains('Failed') || s.contains('Closed')) {
        if (!mounted) return;
        setState(() {
          _dataChannelOpen = false;
          _peerConnected = false;
          _statusText = 'Peer disconnected';
        });
        _addSystemMessage('⚠️ Peer disconnected.');
      }
      // 'Disconnected' is transient — WebRTC auto-retries ICE
    };
  }

  /// BUG 14 FIX: strip path separators so a hostile peer can't write outside the download dir
  String _sanitizeFileName(String name) {
    // Keep only the final component and replace unsafe chars
    final base = name.split('/').last.split('\\').last;
    return base.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }

  void _addMessage(String text, {required bool isMe}) {
    setState(() => _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: text,
          isMe: isMe,
          timestamp: DateTime.now(),
          type: ChatMessageType.text,
        )));
    _scrollToBottom();
  }

  void _addSystemMessage(String text) {
    setState(() => _messages.add(ChatMessage(
          id: const Uuid().v4(),
          text: text,
          isMe: false,
          timestamp: DateTime.now(),
          type: ChatMessageType.system,
        )));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_dataChannelOpen) return;
    _webrtc.sendText(text);
    _addMessage(text, isMe: true);
    _msgCtrl.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached && !_isFilePickerOpen) {
      _wipeAndClose();
    }
  }

  Future<void> _wipeAndClose() async {
    if (!mounted) return;
    try {
      await _webrtc.dispose();
      _signaling.dispose();
    } catch (_) {}
    if (mounted) {
      setState(() => _messages.clear());
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
    await OverlayService.closeGhostChat();
  }

  // BUG 7 FIX: Caller side — track dialog visibility; guard pop against wrong route
  void _openCall({required bool isVideo}) {
    _signaling.sendCallRequest(isVideo);

    _signaling.onCallAccepted = () {
      if (!mounted) return;
      _signaling.onCallAccepted = null;
      _signaling.onCallRejected = null;
      // BUG 7 FIX: only pop if our dialog is still showing
      if (_callingDialogShowing) {
        _callingDialogShowing = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      // BUG 11 FIX: re-wire onConnectionStateChange after returning from call (caller side)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            isVideo: isVideo,
            isCaller: true,
            existingWebRTC: _webrtc,
            existingSignaling: _signaling,
          ),
        ),
      ).then((_) {
        if (!mounted) return;
        _webrtc.onConnectionStateChange = _buildConnectionStateHandler();
      });
    };

    _signaling.onCallRejected = () {
      if (!mounted) return;
      _signaling.onCallAccepted = null;
      _signaling.onCallRejected = null;
      if (_callingDialogShowing) {
        _callingDialogShowing = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('📵 Call was declined'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ));
    };

    _callingDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Text(
            isVideo ? '📹 Video Calling...' : '📞 Audio Calling...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const CircularProgressIndicator(color: Colors.deepPurple),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              _signaling.sendCallEnd();
              _signaling.onCallAccepted = null;
              _signaling.onCallRejected = null;
              _callingDialogShowing = false;
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            label: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ]),
      ),
    ).then((_) {
      // Dialog dismissed (any path)
      _callingDialogShowing = false;
    });
  }

  void _openFileShare() {
    setState(() => _isFilePickerOpen = true);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FileShareScreen(webrtc: _webrtc)),
    ).then((_) {
      if (mounted) setState(() => _isFilePickerOpen = false);
    });
  }

  // BUG 6 FIX: Navigate to ScreenShareScreen (dedicated UI) instead of calling addScreenShare() directly
  void _openScreenShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScreenShareScreen(roomId: widget.roomId, myId: widget.myId),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webrtc.dispose();
    _signaling.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GhostTheme.bg,
      appBar: AppBar(
        backgroundColor: GhostTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GhostTheme.textSecondary),
          onPressed: _wipeAndClose,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room: ${widget.roomId}',
              style: const TextStyle(
                color: GhostTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              _statusText,
              style: TextStyle(
                color: _peerConnected
                    ? GhostTheme.green
                    : GhostTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.attach_file, color: GhostTheme.textSecondary),
            onPressed: _dataChannelOpen ? _openFileShare : null,
            tooltip: 'Share file',
          ),
          IconButton(
            icon: const Icon(Icons.screen_share, color: GhostTheme.accent),
            onPressed: _peerConnected ? _openScreenShare : null,
            tooltip: 'Share screen',
          ),
          IconButton(
            icon: const Icon(Icons.call, color: GhostTheme.green),
            onPressed: _peerConnected ? () => _openCall(isVideo: false) : null,
            tooltip: 'Audio call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.blue),
            onPressed: _peerConnected ? () => _openCall(isVideo: true) : null,
            tooltip: 'Video call',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: GhostTheme.red),
            onPressed: _wipeAndClose,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_peerConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: GhostTheme.card,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: GhostTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _statusText,
                    style: const TextStyle(
                        color: GhostTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👻', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          _peerConnected
                              ? 'Connected! Send a message.'
                              : 'Share the room code with your peer.',
                          style: const TextStyle(
                            color: GhostTheme.textHint,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => MessageBubble(message: _messages[i]),
                  ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: GhostTheme.surface,
              border: Border(top: BorderSide(color: GhostTheme.border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    enabled: _dataChannelOpen,
                    style: const TextStyle(
                        color: GhostTheme.textPrimary, fontSize: 15),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: _dataChannelOpen
                          ? 'Type a message...'
                          : 'Waiting for peer...',
                      hintStyle: const TextStyle(color: GhostTheme.textHint),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _dataChannelOpen
                          ? GhostTheme.accent
                          : GhostTheme.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
