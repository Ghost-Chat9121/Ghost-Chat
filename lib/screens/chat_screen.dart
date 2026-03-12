import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/overlay_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  const ChatScreen({super.key, required this.roomId, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late SignalingService _signaling;
  late WebRTCService _webrtc;
  final List<Map<String, String>> _messages = [];
  final _msgController = TextEditingController();
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnection();
  }

  Future<void> _initConnection() async {
    _signaling = SignalingService(
      roomId: widget.roomId,
      userId: widget.userId,
    );
    _webrtc = WebRTCService(signaling: _signaling);

    // Text messages arrive here
    _webrtc.onMessage = (RTCDataChannelMessage msg) {
      if (!msg.isBinary) {
        setState(() {
          _messages.add({'from': 'peer', 'text': msg.text});
        });
      }
    };

    _signaling.onPeerJoined = () async {
      setState(() {
        _connected = true;
      });
      await _webrtc.createOffer();
    };

    _signaling.onPeerLeft = () {
      setState(() => _connected = false);
      _showSnack('Peer disconnected. Session wiped.');
    };

    await _webrtc.initialize(audio: false, video: false);
    _signaling.connect();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty || !_connected) return;
    _webrtc.sendMessage(text);
    setState(() => _messages.add({'from': 'me', 'text': text}));
    _msgController.clear();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── Auto-wipe on minimize ────────────────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wipeAndClose();
    }
  }

  Future<void> _wipeAndClose() async {
    await _webrtc.dispose();
    _signaling.dispose();
    _messages.clear();
    await OverlayService.closeGhostChat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webrtc.dispose();
    _signaling.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room: ${widget.roomId}',
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            Text(
              _connected ? '🟢 Peer Connected' : '🔴 Waiting for peer...',
              style: const TextStyle(color: Colors.green, fontSize: 11),
            ),
          ],
        ),
        actions: [
          // ─── Start audio call ─────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: _connected
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        roomId: widget.roomId,
                        userId: widget.userId,
                        isVideo: false,
                      ),
                    ))
                : null,
          ),
          // ─── Start video call ─────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.blue),
            onPressed: _connected
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        roomId: widget.roomId,
                        userId: widget.userId,
                        isVideo: true,
                      ),
                    ))
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _wipeAndClose,
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Messages list ────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isMe = msg['from'] == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.deepPurple : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          // ─── Input bar ────────────────────────────────────────────────
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _connected
                          ? 'Type a message...'
                          : 'Waiting for peer...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
