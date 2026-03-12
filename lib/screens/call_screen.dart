import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String roomId;
  final String userId;
  final bool isVideo;
  const CallScreen({
    super.key,
    required this.roomId,
    required this.userId,
    required this.isVideo,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  late SignalingService _signaling;
  late WebRTCService _webrtc;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _muted = false;
  bool _cameraOff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCall();
  }

  Future<void> _startCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling = SignalingService(
        roomId: '${widget.roomId}_call', userId: widget.userId);
    _webrtc = WebRTCService(signaling: _signaling);

    _webrtc.onRemoteStream = (stream) {
      setState(() => _remoteRenderer.srcObject = stream);
    };

    await _webrtc.initialize(audio: true, video: widget.isVideo);

    setState(() => _localRenderer.srcObject = _webrtc.localStream);

    _signaling.onPeerJoined = () async => await _webrtc.createOffer();
    _signaling.connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _endCall();
    }
  }

  Future<void> _endCall() async {
    await _webrtc.dispose();
    _signaling.dispose();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webrtc.dispose();
    _signaling.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Remote video (full screen) ───────────────────────────────
          if (widget.isVideo)
            Positioned.fill(
              child: RTCVideoView(_remoteRenderer, mirror: false),
            )
          else
            const Center(
              child: Icon(Icons.person, color: Colors.white54, size: 100),
            ),

          // ─── Local video (picture-in-picture) ──────────────────────────
          if (widget.isVideo)
            Positioned(
              right: 16,
              top: 40,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),

          // ─── Call controls ─────────────────────────────────────────────
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _callButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  color: _muted ? Colors.red : Colors.white,
                  onTap: () {
                    _webrtc.toggleMute();
                    setState(() => _muted = !_muted);
                  },
                ),
                _callButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 60,
                  onTap: _endCall,
                ),
                if (widget.isVideo)
                  _callButton(
                    icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _cameraOff ? Colors.red : Colors.white,
                    onTap: () {
                      _webrtc.toggleCamera();
                      setState(() => _cameraOff = !_cameraOff);
                    },
                  ),
                if (widget.isVideo)
                  _callButton(
                    icon: Icons.flip_camera_ios,
                    color: Colors.white,
                    onTap: _webrtc.switchCamera,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    double size = 50,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFF2A2A2A),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
