import 'package:socket_io_client/socket_io_client.dart' as IO;

// ─── Signaling server URL — deploy server/server.js on Render ─────────────────
const String kSignalingServer = 'https://your-signaling-server.onrender.com';

class SignalingService {
  late IO.Socket socket;
  final String roomId;
  final String userId;

  // Callbacks
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function()? onPeerJoined;
  Function()? onPeerLeft;

  SignalingService({required this.roomId, required this.userId});

  void connect() {
    socket = IO.io(
        kSignalingServer,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build());

    socket.connect();

    socket.onConnect((_) {
      socket.emit('join-room', {'roomId': roomId, 'userId': userId});
    });

    socket.on('peer-joined', (_) => onPeerJoined?.call());
    socket.on('peer-left', (_) => onPeerLeft?.call());

    socket.on(
        'offer', (data) => onOffer?.call(Map<String, dynamic>.from(data)));
    socket.on(
        'answer', (data) => onAnswer?.call(Map<String, dynamic>.from(data)));
    socket.on('ice-candidate',
        (data) => onIceCandidate?.call(Map<String, dynamic>.from(data)));
  }

  void sendOffer(Map<String, dynamic> offer) =>
      socket.emit('offer', {'roomId': roomId, 'offer': offer});

  void sendAnswer(Map<String, dynamic> answer) =>
      socket.emit('answer', {'roomId': roomId, 'answer': answer});

  void sendIceCandidate(Map<String, dynamic> candidate) =>
      socket.emit('ice-candidate', {'roomId': roomId, 'candidate': candidate});

  void dispose() {
    socket.disconnect();
    socket.dispose();
  }
}
