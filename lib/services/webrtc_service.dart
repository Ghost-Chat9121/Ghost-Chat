import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCDataChannel? dataChannel;

  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(RTCDataChannelMessage)? onMessage;
  Function(RTCDataChannel)? onDataChannel;

  final SignalingService signaling;

  WebRTCService({required this.signaling});

  // ─── ICE & STUN configuration ──────────────────────────────────────────────
  final Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initialize({bool video = false, bool audio = true}) async {
    // Get local media stream
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': audio,
      'video':
          video ? {'facingMode': 'user', 'width': 640, 'height': 480} : false,
    });

    // Create peer connection
    _peerConnection = await createPeerConnection(_rtcConfig);

    // Add local tracks to connection
    localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream!);
    });

    // ─── Handle incoming remote stream ────────────────────────────────────────
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };

    // ─── Handle ICE candidates ─────────────────────────────────────────────
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      signaling.sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    // ─── Create DataChannel for text chat and file transfer ───────────────────
    dataChannel = await _peerConnection!.createDataChannel(
      'ghostchat',
      RTCDataChannelInit()..ordered = true,
    );
    dataChannel!.onMessage = (msg) => onMessage?.call(msg);

    // ─── Handle incoming DataChannel from remote peer ─────────────────────────
    _peerConnection!.onDataChannel = (channel) {
      dataChannel = channel;
      dataChannel!.onMessage = (msg) => onMessage?.call(msg);
      onDataChannel?.call(channel);
    };

    // ─── Wire up signaling callbacks ──────────────────────────────────────────
    signaling.onOffer = (data) async {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      signaling.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
    };

    signaling.onAnswer = (data) async {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['answer']['sdp'], data['answer']['type']),
      );
    };

    signaling.onIceCandidate = (data) async {
      await _peerConnection!.addCandidate(RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      ));
    };
  }

  // ─── Caller initiates offer ────────────────────────────────────────────────
  Future<void> createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    signaling.sendOffer({'sdp': offer.sdp, 'type': offer.type});
  }

  // ─── Send text message via DataChannel ────────────────────────────────────
  void sendMessage(String message) {
    dataChannel?.send(RTCDataChannelMessage(message));
  }

  // ─── Send file as binary chunks via DataChannel ───────────────────────────
  Future<void> sendFile(List<int> bytes, String fileName) async {
    const chunkSize = 16384; // 16KB chunks
    // Send filename header first
    dataChannel
        ?.send(RTCDataChannelMessage('FILE_START:$fileName:${bytes.length}'));
    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      dataChannel?.send(RTCDataChannelMessage.fromBinary(
        Uint8List.fromList(bytes.sublist(i, end)),
      ));
      await Future.delayed(const Duration(milliseconds: 10)); // flow control
    }
    dataChannel?.send(RTCDataChannelMessage('FILE_END:$fileName'));
  }

  // ─── Toggle camera/mic ────────────────────────────────────────────────────
  void toggleMute() {
    localStream?.getAudioTracks().forEach((t) => t.enabled = !t.enabled);
  }

  void toggleCamera() {
    localStream?.getVideoTracks().forEach((t) => t.enabled = !t.enabled);
  }

  void switchCamera() =>
      Helper.switchCamera(localStream!.getVideoTracks().first);

  // ─── Clean wipe — nothing persists ────────────────────────────────────────
  Future<void> dispose() async {
    dataChannel?.close();
    localStream?.getTracks().forEach((t) => t.stop());
    await localStream?.dispose();
    remoteStream?.getTracks().forEach((t) => t.stop());
    await remoteStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    localStream = null;
    remoteStream = null;
    dataChannel = null;
  }
}
