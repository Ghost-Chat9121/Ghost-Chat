enum TransferStatus { pending, inProgress, done, failed }

class FileTransfer {
  final String fileName;
  final int totalSize;
  int receivedBytes;
  TransferStatus status;
  List<int> buffer;

  FileTransfer({
    required this.fileName,
    required this.totalSize,
  })  : receivedBytes = 0,
        status = TransferStatus.pending,
        buffer = [];

  double get progress => totalSize == 0 ? 0 : receivedBytes / totalSize;
}
