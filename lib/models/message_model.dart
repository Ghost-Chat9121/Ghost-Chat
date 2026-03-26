enum ChatMessageType {
  text,
  fileStart,
  fileChunk,
  fileEnd,
  system,
  image,
  file
}

class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  final ChatMessageType type;
  final String? imagePath; // ✅ local path to image for preview
  final String? filePath; // ✅ local path for any file

  ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.type = ChatMessageType.text, // ✅ default uses the correct enum
    this.imagePath,
    this.filePath,
  });
}
