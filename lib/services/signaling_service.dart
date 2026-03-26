import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const String kSignalingServer = 'https://ghost-chat-akdw.onrender.com';

class SignalingService {
  late io.Socket socket;
  final String roomId;
  final String userId;

  Function(Map)? onOffer;
  Function(Map)? onAnswer;
  Function(Map)? onIceCandidate;
  Function()? onPeerJoined;
  Function()? onPeerAlready;
  Function()? onPeerLeft;
  Function()? onCallEnded;
  Function(bool isVideo)? onIncomingCall;
  Function()? onCallAccepted;
  Function()? onCallRejected;
  Function(String)? onRoomFull;
  Function(String)? onError;

  SignalingService({required this.roomId, required this.userId});

  void connect() {
    // ✅ If socket already exists and is connected, skip reconnect
    try {
      if (socket.connected) {
        debugPrint('⚡ Already connected, skipping reconnect');
        return;
      }
    } catch (_) {
      // socket not initialized yet → we'll create it below
    }

    socket = io.io(
      kSignalingServer,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setTimeout(60000)
          .setReconnectionAttempts(5)
          .setReconnectionDelay(3000)
          .enableReconnection()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      debugPrint('✅ Signaling server connected');
      socket.emit('join-room', {'roomId': roomId, 'userId': userId});
    });

    socket.onConnectError((e) {
      debugPrint('❌ Connect error: $e');
      onError?.call('Cannot reach server. Retrying...');
    });

    socket.onDisconnect((_) {
      debugPrint('⚠️ Signaling disconnected');
      // no onPeerLeft here; 'peer-left' event handles it
    });

    socket.on('peer-joined', (_) {
      debugPrint('👥 peer-joined');
      onPeerJoined?.call();
    });

    socket.on('peer-already-in-room', (_) {
      debugPrint('👥 peer-already-in-room');
      onPeerAlready?.call();
    });

    socket.on('peer-left', (_) {
      debugPrint('👋 peer-left');
      onPeerLeft?.call();
    });

    socket.on('call-ended', (_) {
      debugPrint('📵 call-ended by peer');
      onCallEnded?.call();
    });

    socket.on('call-request', (data) {
      final isVideo = (data['isVideo'] as bool?) ?? false;
      debugPrint('📞 incoming call (video: $isVideo)');
      onIncomingCall?.call(isVideo);
    });

    socket.on('call-accepted', (_) {
      debugPrint('✅ call accepted by peer');
      onCallAccepted?.call();
    });

    socket.on('call-rejected', (_) {
      debugPrint('❌ call rejected by peer');
      onCallRejected?.call();
    });

    socket.on('room-full', (_) => onRoomFull?.call('Room is full.'));

    socket.on('offer', (data) => onOffer?.call(Map.from(data)));
    socket.on('answer', (data) => onAnswer?.call(Map.from(data)));
    socket.on('ice-candidate', (data) => onIceCandidate?.call(Map.from(data)));
  }

  void sendOffer(Map offer) =>
      socket.emit('offer', {'roomId': roomId, 'offer': offer});

  void sendAnswer(Map answer) =>
      socket.emit('answer', {'roomId': roomId, 'answer': answer});

  void sendIceCandidate(Map candidate) =>
      socket.emit('ice-candidate', {'roomId': roomId, 'candidate': candidate});

  void sendCallEnd() => socket.emit('call-end', {'roomId': roomId});

  void sendCallRequest(bool isVideo) =>
      socket.emit('call-request', {'roomId': roomId, 'isVideo': isVideo});

  void sendCallAccept() => socket.emit('call-accept', {'roomId': roomId});

  void sendCallReject() => socket.emit('call-reject', {'roomId': roomId});

  void dispose() {
    try {
      socket.disconnect();
      socket.dispose();
    } catch (_) {}
  }
}
