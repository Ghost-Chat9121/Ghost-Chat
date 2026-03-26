import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';
import 'package:flutter/services.dart';

class WebRTCService {
  RTCPeerConnection? _pc;
  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCDataChannel? _dataChannel;
  static const _foregroundServiceChannel =
      MethodChannel('com.example.ghost_chat/foreground_service');

  final SignalingService signaling;

  Function(MediaStream)? onRemoteStream;
  Function(String text)? onTextMessage;
  Function(String header)? onFileStart;
  Function(Uint8List chunk)? onFileChunk;
  Function(String fileName)? onFileEnd;
  Function(RTCPeerConnectionState)? onConnectionStateChange;
  Function(String error)? onScreenShareError;

  // BUG 3 FIX: Expose data channel open/close events to the UI
  Function()? onDataChannelOpen;
  Function()? onDataChannelClosed;

  bool _isDisposed = false;
  bool _remoteDescSet = false;
  bool _isScreenSharing = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  // BUG 9 FIX: make _audioRenderer nullable; create fresh on each initialize()
  RTCVideoRenderer? _audioRenderer;

  WebRTCService({required this.signaling});

  bool get isConnected =>
      _pc?.connectionState ==
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  static const Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': 'dc714fae6b0bda6030cd8d99',
        'credential': 'tpC4APQgK7R2Lk6E',
      },
      {
        'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
        'username': 'dc714fae6b0bda6030cd8d99',
        'credential': 'tpC4APQgK7R2Lk6E',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': 'dc714fae6b0bda6030cd8d99',
        'credential': 'tpC4APQgK7R2Lk6E',
      },
      {
        'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
        'username': 'dc714fae6b0bda6030cd8d99',
        'credential': 'tpC4APQgK7R2Lk6E',
      },
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  Future<void> initialize({
    bool audio = false,
    bool video = false,
    bool screenShare = false,
  }) async {
    await _teardown();

    // BUG 9 FIX: create a fresh renderer each time (old one was disposed in _teardown)
    _audioRenderer = RTCVideoRenderer();
    await _audioRenderer!.initialize();
    _isDisposed = false;

    if (audio || video || screenShare) {
      try {
        if (screenShare) {
          localStream = await navigator.mediaDevices
              .getDisplayMedia({'video': true, 'audio': true});
        } else {
          localStream = await navigator.mediaDevices.getUserMedia({
            'audio': audio,
            'video': video
                ? {'facingMode': 'user', 'width': 1280, 'height': 720}
                : false,
          });
        }
      } catch (e) {
        debugPrint('⚠️ getUserMedia failed: $e');
        localStream = null;
      }
    } else {
      localStream = null;
    }

    _pc = await createPeerConnection(_iceConfig);

    if (localStream != null) {
      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
      }
    }

    _pc!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];

        debugPrint('📥 Remote stream received: ${event.streams[0].id}');
        debugPrint(
            '📥 Track kinds: ${event.streams[0].getTracks().map((t) => t.kind).toList()}');

        // Ensure audio tracks are enabled
        for (final track in event.streams[0].getTracks()) {
          if (track.kind == 'audio') {
            debugPrint('🔊 Audio track found - ensuring enabled');
            track.enabled = true;
          }
        }

        // Attach remote stream to audio renderer
        _audioRenderer?.srcObject = remoteStream;

        onRemoteStream?.call(remoteStream!);

        debugPrint('🔊 Remote audio attached to renderer');
      }
    };

    _pc!.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate != null) {
        signaling.sendIceCandidate({
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
        });
      }
    };

    _pc!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('🔗 PC state: $state');
      onConnectionStateChange?.call(state);
    };

    _pc!.onDataChannel = (channel) {
      debugPrint('📡 Incoming data channel');
      _dataChannel = channel;
      _setupDataChannelListeners(channel);
    };

    signaling.onOffer = (data) async {
      if (_isDisposed || _pc == null) return;
      debugPrint('📨 Got offer → creating answer');
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
      );
      _remoteDescSet = true;

      for (final c in _pendingCandidates) {
        try {
          await _pc!.addCandidate(c);
        } catch (_) {}
      }
      _pendingCandidates.clear();

      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      signaling.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
    };

    signaling.onAnswer = (data) async {
      if (_isDisposed || _pc == null) return;
      debugPrint('📨 Got answer');
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
      _remoteDescSet = true;

      for (final c in _pendingCandidates) {
        try {
          await _pc!.addCandidate(c);
        } catch (e) {
          debugPrint('⚠️ addCandidate failed: $e');
        }
      }
      _pendingCandidates.clear();
    };

    signaling.onIceCandidate = (data) async {
      if (_isDisposed || _pc == null) return;
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      if (_remoteDescSet) {
        try {
          await _pc!.addCandidate(candidate);
        } catch (e) {
          debugPrint('⚠️ addCandidate failed: $e');
        }
      } else {
        debugPrint('⏳ Buffering ICE candidate');
        _pendingCandidates.add(candidate);
      }
    };

    debugPrint('✅ WebRTC initialized');
  }

  Future<void> addMediaForCall({
    required bool audio,
    required bool video,
  }) async {
    if (_pc == null) return;

    debugPrint('📞 addMediaForCall: audio=$audio, video=$video');

    final senders = await _pc!.getSenders();
    for (final sender in senders) {
      if (sender.track?.kind == 'audio' || sender.track?.kind == 'video') {
        await _pc!.removeTrack(sender);
      }
    }

    if (localStream != null) {
      localStream!.getTracks().forEach((t) => t.stop());
      await localStream!.dispose();
      localStream = null;
    }

    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': audio
            ? {
                'echoCancellation': true,
                'noiseSuppression': true,
                'autoGainControl': true,
              }
            : false,
        'video': video
            ? {'facingMode': 'user', 'width': 1280, 'height': 720}
            : false,
      });

      debugPrint(
          '📞 Got local stream with tracks: ${localStream!.getTracks().map((t) => t.kind).toList()}');

      for (final track in localStream!.getTracks()) {
        await _pc!.addTrack(track, localStream!);
        debugPrint('📤 Added track: ${track.kind}');
      }

      debugPrint('✅ Media tracks added for call');
    } catch (e) {
      debugPrint('⚠️ addMediaForCall getUserMedia failed: $e');
      localStream = null;
    }
  }

  void _setupDataChannelListeners(RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      debugPrint('📡 DataChannel: $state');
      // BUG 3 FIX: fire open/close callbacks so UI can accurately track send-readiness
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        onDataChannelOpen?.call();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed ||
          state == RTCDataChannelState.RTCDataChannelClosing) {
        onDataChannelClosed?.call();
      }
    };
    channel.onMessage = (RTCDataChannelMessage msg) {
      if (!msg.isBinary) {
        final text = msg.text;
        if (text.startsWith('FILE_START:')) {
          onFileStart?.call(text);
        } else if (text.startsWith('FILE_END:')) {
          onFileEnd?.call(text.replaceFirst('FILE_END:', ''));
        } else {
          onTextMessage?.call(text);
        }
      } else {
        onFileChunk?.call(msg.binary);
      }
    };
  }

  Future<void> createOffer() async {
    if (_pc == null) return;
    if (_dataChannel == null) {
      final dcInit = RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;
      _dataChannel = await _pc!.createDataChannel('ghost_data', dcInit);
      _setupDataChannelListeners(_dataChannel!);
    }
    debugPrint('📤 Sending offer...');
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _pc!.setLocalDescription(offer);
    signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> renegotiate() async {
    if (_pc == null) return;
    try {
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _pc!.setLocalDescription(offer);
      signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
      debugPrint('🔄 Renegotiation offer sent');
    } catch (e) {
      debugPrint('⚠️ renegotiate failed: $e');
    }
  }

  Future<void> addScreenShare() async {
    if (_pc == null) {
      onScreenShareError?.call('Connection not ready');
      return;
    }

    _isScreenSharing = true;

    try {
      debugPrint('🖥️ Starting screen share...');

      // Start foreground service FIRST (Android 14+ requirement)
      try {
        await _foregroundServiceChannel.invokeMethod('startService');
        debugPrint('✅ Foreground service started');
      } on PlatformException catch (e) {
        debugPrint('⚠️ Foreground service error: ${e.message}');
        // Continue anyway - service might already be running
      }

      final screenStream = await navigator.mediaDevices
          .getDisplayMedia({'video': true, 'audio': false});

      if (screenStream.getVideoTracks().isEmpty) {
        throw Exception('No video track available');
      }

      final screenTrack = screenStream.getVideoTracks().first;

      screenTrack.onEnded = () {
        debugPrint('🖥️ Screen share ended by user');
        _isScreenSharing = false;
      };

      final senders = await _pc!.getSenders();
      RTCRtpSender? videoSender;
      for (final s in senders) {
        if (s.track?.kind == 'video') {
          videoSender = s;
          break;
        }
      }

      if (videoSender != null) {
        await videoSender.replaceTrack(screenTrack);
        debugPrint('🖥️ Replaced video track with screen');
      } else {
        await _pc!.addTrack(screenTrack, screenStream);
        debugPrint('🖥️ Added screen track');
      }

      if (localStream != null) {
        for (final track in localStream!.getVideoTracks()) {
          track.stop();
        }
      }

      localStream = screenStream;
      await renegotiate();

      _isScreenSharing = true;
      debugPrint('✅ Screen share started successfully');
    } catch (e) {
      debugPrint('❌ Screen share failed: $e');
      _isScreenSharing = false;

      // Stop foreground service on failure
      try {
        await _foregroundServiceChannel.invokeMethod('stopService');
      } catch (_) {}

      String errorMessage;
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission') ||
          errorStr.contains('denied') ||
          errorStr.contains('notallowed')) {
        errorMessage =
            'Screen sharing permission denied. Please allow screen capture.';
      } else if (errorStr.contains('notfound') ||
          errorStr.contains('not found') ||
          errorStr.contains('abort')) {
        errorMessage = 'Screen sharing cancelled or no screen available.';
      } else if (errorStr.contains('timeout')) {
        errorMessage = 'Screen selection timed out. Please try again.';
      } else {
        errorMessage = 'Screen sharing failed. Please try again.';
      }

      onScreenShareError?.call(errorMessage);
    }
  }

  Future<void> stopScreenShare({required bool video}) async {
    if (_pc == null) {
      debugPrint('⚠️ stopScreenShare: _pc is null');
      return;
    }

    try {
      debugPrint('🖥️ Stopping screen share...');

      if (video) {
        final camStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {'facingMode': 'user', 'width': 1280, 'height': 720},
        });

        final camTrack = camStream.getVideoTracks().first;

        final senders = await _pc!.getSenders();
        for (final s in senders) {
          if (s.track?.kind == 'video') {
            await s.replaceTrack(camTrack);
            break;
          }
        }

        if (localStream != null) {
          for (final track in localStream!.getTracks()) {
            track.stop();
          }
          await localStream!.dispose();
        }

        localStream = camStream;
        debugPrint('✅ Camera restored after screen share');
      } else {
        if (localStream != null) {
          for (final track in localStream!.getTracks()) {
            track.stop();
          }
          await localStream!.dispose();
          localStream = null;
        }
      }

      _isScreenSharing = false;

      // Stop foreground service
      try {
        await _foregroundServiceChannel.invokeMethod('stopService');
      } catch (_) {}

      await renegotiate();
    } catch (e) {
      debugPrint('❌ stopScreenShare failed: $e');
      _isScreenSharing = false;
    }
  }

  void sendText(String message) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(message));
    } else {
      debugPrint('⚠️ sendText skipped — channel: ${_dataChannel?.state}');
    }
  }

  void sendBinaryChunk(Uint8List data) {
    if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(data));
    }
  }

  Future<void> sendFile(List<int> bytes, String fileName) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    const chunkSize = 16384;
    _dataChannel!
        .send(RTCDataChannelMessage('FILE_START:$fileName:${bytes.length}'));
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      _dataChannel!.send(RTCDataChannelMessage.fromBinary(
          Uint8List.fromList(bytes.sublist(i, end))));
      await Future.delayed(const Duration(milliseconds: 15));
    }
    _dataChannel!.send(RTCDataChannelMessage('FILE_END:$fileName'));
  }

  /// Stop call media tracks without destroying the peer connection.
  /// Call this when ending a voice/video call to release mic and camera.
  Future<void> stopCallMedia() async {
    try {
      if (localStream != null) {
        localStream!.getTracks().forEach((t) => t.stop());
        await localStream!.dispose();
        localStream = null;
        debugPrint('🎙️ Call media tracks stopped');
      }
    } catch (e) {
      debugPrint('⚠️ stopCallMedia failed: $e');
    }
  }

  void toggleMute() {
    if (localStream != null) {
      localStream!.getAudioTracks().forEach((t) {
        t.enabled = !t.enabled;
        debugPrint('🔇 Mute toggled: ${!t.enabled}');
      });
    }
  }

  void toggleCamera() {
    if (localStream != null) {
      localStream!.getVideoTracks().forEach((t) {
        t.enabled = !t.enabled;
        debugPrint('📹 Camera toggled: ${t.enabled}');
      });
    }
  }

  void switchCamera() {
    final tracks = localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) Helper.switchCamera(tracks.first);
  }

  Future<void> setSpeakerOn(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
      debugPrint('🔊 Speaker: $on');
    } catch (e) {
      debugPrint('⚠️ setSpeakerphoneOn failed: $e');
    }
  }

  bool get isMuted {
    final t = localStream?.getAudioTracks();
    return t != null && t.isNotEmpty && !t.first.enabled;
  }

  bool get isCameraOff {
    final t = localStream?.getVideoTracks();
    return t != null && t.isNotEmpty && !t.first.enabled;
  }

  bool get isScreenSharing => _isScreenSharing;

  Future<void> _teardown() async {
    try {
      _dataChannel?.close();
      localStream?.getTracks().forEach((t) => t.stop());
      await localStream?.dispose();
      remoteStream?.getTracks().forEach((t) => t.stop());
      await remoteStream?.dispose();
      await _pc?.close();
      // BUG 9 FIX: dispose and null _audioRenderer so initialize() creates a fresh one
      await _audioRenderer?.dispose();
      _audioRenderer = null;
    } catch (_) {}
    _pc = null;
    localStream = null;
    remoteStream = null;
    _dataChannel = null;
    _pendingCandidates.clear();
    _remoteDescSet = false;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _teardown();
  }
}
