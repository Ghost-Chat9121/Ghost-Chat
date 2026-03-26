import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app/theme.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_service.dart';
import '../services/overlay_service.dart';
import '../widgets/call_control_button.dart';

class CallScreen extends StatefulWidget {
  final bool isVideo;
  final bool isCaller;
  final WebRTCService existingWebRTC;
  final SignalingService existingSignaling;

  const CallScreen({
    super.key,
    required this.isVideo,
    required this.isCaller,
    required this.existingWebRTC,
    required this.existingSignaling,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with WidgetsBindingObserver {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _muted = false;
  bool _cameraOff = false;
  bool _connected = false;
  bool _speakerOn = true;
  bool _ended = false;
  bool _screenSharing = false;
  String _status = 'Starting call...';

  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCall();
  }

  Future<void> _startCall() async {
    await [Permission.camera, Permission.microphone].request();

    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // ✅ Wire remote stream BEFORE adding media
    widget.existingWebRTC.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _connected = true;
        _status = 'Connected';
      });
      _startTimer();

      // ✅ CRITICAL: Enable speaker when remote stream arrives
      widget.existingWebRTC.setSpeakerOn(true);
    };

    // ✅ Only react to Failed/Closed
    widget.existingWebRTC.onConnectionStateChange = (state) {
      final s = state.toString();
      if (s.contains('Failed') || s.contains('Closed')) {
        _endCall();
      }
    };

    widget.existingSignaling.onCallEnded = () {
      _endCall(notifyPeer: false);
    };

    widget.existingWebRTC.onScreenShareError = (error) {
      debugPrint('❌ Screen share error: $error'); // Add this line
      if (!mounted) return;
      setState(() => _screenSharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    };

    // ✅ Add media tracks to existing peer connection
    try {
      await widget.existingWebRTC.addMediaForCall(
        audio: true,
        video: widget.isVideo,
      );
    } catch (e) {
      debugPrint('❌ addMediaForCall failed: $e');
    }

    if (!mounted) return;

    setState(() {
      _localRenderer.srcObject = widget.existingWebRTC.localStream;
      if (widget.existingWebRTC.remoteStream != null) {
        _remoteRenderer.srcObject = widget.existingWebRTC.remoteStream;
        _connected = true;
        _status = 'Connected';
        _startTimer();
      } else {
        _status = 'Ringing...';
      }
    });

    // ✅ Enable speaker on outgoing call
    await widget.existingWebRTC.setSpeakerOn(true);

    // ✅ Only the CALLER sends the offer
    if (widget.isCaller) {
      try {
        await widget.existingWebRTC.createOffer();
      } catch (e) {
        debugPrint('❌ Call createOffer failed: $e');
      }
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _callDuration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall({bool notifyPeer = true}) async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    if (notifyPeer) {
      widget.existingSignaling.sendCallEnd();
    }
    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleScreenShare() async {
    // Prevent multiple taps
    if (_screenSharing) {
      // Stop screen sharing
      try {
        await widget.existingWebRTC.stopScreenShare(video: widget.isVideo);
        if (mounted) {
          setState(() {
            _screenSharing = false;
            _localRenderer.srcObject = widget.existingWebRTC.localStream;
          });
        }
      } catch (e) {
        debugPrint('❌ stopScreenShare error: $e');
        if (mounted) {
          setState(() => _screenSharing = false);
        }
      }
    } else {
      // Start screen sharing
      try {
        // Set state first
        if (mounted) {
          setState(() {
            _screenSharing = true;
            _status = 'Starting screen share...';
          });
        }

        // Call the screen share method
        await widget.existingWebRTC.addScreenShare();

        // If successful, update the renderer
        if (mounted && widget.existingWebRTC.localStream != null) {
          setState(() {
            _localRenderer.srcObject = widget.existingWebRTC.localStream;
            _status = 'Screen sharing';
          });
        }
      } catch (e) {
        debugPrint('❌ addScreenShare error: $e');
        // Error is already handled by onScreenShareError callback
        if (mounted) {
          setState(() => _screenSharing = false);
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _endCall(notifyPeer: true);
      OverlayService.closeGhostChat();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_ended) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Remote video / audio background ──────────────────────────
          Positioned.fill(
            child: widget.isVideo && _connected
                ? RTCVideoView(_remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A0533), Color(0xFF0A0A0F)],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: GhostTheme.accent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: GhostTheme.accent, width: 2),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white54, size: 50),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _connected ? _callDuration : _status,
                          style: TextStyle(
                            color: _connected
                                ? GhostTheme.green
                                : GhostTheme.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ── Local video PiP ──────────────────────────────────────────
          if (widget.isVideo || _screenSharing)
            Positioned(
              right: 16,
              top: 48,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(_localRenderer, mirror: !_screenSharing),
              ),
            ),

          // ── Top status bar ───────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.isVideo ? '📹 Video Call' : '📞 Audio Call',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (_connected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: GhostTheme.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: GhostTheme.green),
                        ),
                        child: Text(
                          '🔒 P2P $_callDuration',
                          style: const TextStyle(
                              color: GhostTheme.green, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Call controls ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, bottom: 40, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Row 1: main controls ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CallControlButton(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        iconColor: _muted ? GhostTheme.red : Colors.white,
                        bgColor: _muted
                            ? GhostTheme.red.withValues(alpha: 0.2)
                            : GhostTheme.card,
                        label: _muted ? 'Unmute' : 'Mute',
                        onTap: () {
                          widget.existingWebRTC.toggleMute();
                          setState(() => _muted = !_muted);
                        },
                      ),
                      CallControlButton(
                        icon: Icons.call_end,
                        iconColor: Colors.white,
                        bgColor: GhostTheme.red,
                        label: 'End',
                        size: 68,
                        onTap: () => _endCall(notifyPeer: true),
                      ),
                      if (widget.isVideo)
                        CallControlButton(
                          icon:
                              _cameraOff ? Icons.videocam_off : Icons.videocam,
                          iconColor: _cameraOff ? GhostTheme.red : Colors.white,
                          bgColor: _cameraOff
                              ? GhostTheme.red.withValues(alpha: 0.2)
                              : GhostTheme.card,
                          label: _cameraOff ? 'Show' : 'Hide',
                          onTap: () {
                            widget.existingWebRTC.toggleCamera();
                            setState(() => _cameraOff = !_cameraOff);
                          },
                        )
                      else
                        CallControlButton(
                          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                          iconColor: _speakerOn ? Colors.white : GhostTheme.red,
                          bgColor: _speakerOn
                              ? GhostTheme.card
                              : GhostTheme.red.withValues(alpha: 0.2),
                          label: _speakerOn ? 'Speaker' : 'Earpiece',
                          onTap: () async {
                            final val = !_speakerOn;
                            await widget.existingWebRTC.setSpeakerOn(val);
                            setState(() => _speakerOn = val);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Row 2: secondary controls ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.isVideo)
                        CallControlButton(
                          icon: Icons.flip_camera_ios,
                          bgColor: GhostTheme.card,
                          label: 'Flip',
                          onTap: widget.existingWebRTC.switchCamera,
                        ),
                      CallControlButton(
                        icon: _screenSharing
                            ? Icons.stop_screen_share
                            : Icons.screen_share,
                        iconColor:
                            _screenSharing ? GhostTheme.red : Colors.white,
                        bgColor: _screenSharing
                            ? GhostTheme.red.withValues(alpha: 0.2)
                            : GhostTheme.card,
                        label: _screenSharing ? 'Stop Share' : 'Share Screen',
                        onTap: _toggleScreenShare,
                      ),
                      if (widget.isVideo)
                        CallControlButton(
                          icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                          iconColor: _speakerOn ? Colors.white : GhostTheme.red,
                          bgColor: _speakerOn
                              ? GhostTheme.card
                              : GhostTheme.red.withValues(alpha: 0.2),
                          label: _speakerOn ? 'Speaker' : 'Earpiece',
                          onTap: () async {
                            final val = !_speakerOn;
                            await widget.existingWebRTC.setSpeakerOn(val);
                            setState(() => _speakerOn = val);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
