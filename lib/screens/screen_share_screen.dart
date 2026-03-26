import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../app/theme.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/overlay_service.dart';

class ScreenShareScreen extends StatefulWidget {
  final String roomId;
  final String myId;
  const ScreenShareScreen(
      {super.key, required this.roomId, required this.myId});

  @override
  State<ScreenShareScreen> createState() => _ScreenShareScreenState();
}

class _ScreenShareScreenState extends State<ScreenShareScreen>
    with WidgetsBindingObserver {
  late SignalingService _signaling;
  late WebRTCService _webrtc;

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _sharing = false;
  bool _viewing = false;
  String _status = 'Choose what to do';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSignaling();
  }

  Future<void> _initSignaling() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _signaling = SignalingService(
        roomId: '${widget.roomId}_screen', userId: widget.myId);
    _webrtc = WebRTCService(signaling: _signaling);

    _webrtc.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _viewing = true;
        _status = 'Viewing peer\'s screen';
      });
    };

    _webrtc.onConnectionStateChange = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _stopAll();
      }
    };

    _signaling.onPeerJoined = () async {
      await _webrtc.createOffer();
    };
    _signaling.connect();
  }

  Future<void> _startSharing() async {
    setState(() => _status = 'Starting screen share...');
    await _webrtc.initialize(screenShare: true);
    setState(() {
      _localRenderer.srcObject = _webrtc.localStream;
      _sharing = true;
      _status = 'Sharing your screen 🟢';
    });
    await _webrtc.createOffer();
  }

  Future<void> _stopAll() async {
    await _webrtc.dispose();
    _signaling.dispose();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ✅ Remove 'paused' — it fires during WebRTC negotiation and kills the screen
    if (state == AppLifecycleState.detached) {
      _stopAll();
      OverlayService.closeGhostChat();
    }
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
          // ─── Main view (remote screen or local preview) ─────────────────
          Positioned.fill(
            child: (_sharing || _viewing)
                ? RTCVideoView(
                    _viewing ? _remoteRenderer : _localRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.screen_share,
                            color: GhostTheme.textHint, size: 64),
                        const SizedBox(height: 16),
                        Text(_status,
                            style: const TextStyle(
                                color: GhostTheme.textSecondary)),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _startSharing,
                          icon: const Icon(Icons.cast, size: 18),
                          label: const Text('Share My Screen'),
                        ),
                      ],
                    ),
                  ),
          ),

          // ─── Top bar ────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black54,
                child: Row(
                  children: [
                    const Icon(Icons.screen_share,
                        color: GhostTheme.green, size: 18),
                    const SizedBox(width: 8),
                    Text(_status,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _stopAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GhostTheme.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Stop',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
