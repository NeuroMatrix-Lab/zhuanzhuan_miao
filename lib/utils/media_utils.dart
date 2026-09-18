import 'dart:io';

const kMediaExtensions = {
  'mp4', 'avi', 'mkv', 'mov', 'webm', 'wmv', 'flv',
  'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma',
  'gif', 'jpg', 'jpeg', 'png', 'bmp', 'webp',
};

bool isMediaPath(String path) =>
    kMediaExtensions.contains(path.split('.').last.toLowerCase());

String fileNameOf(String path) => path.split(Platform.pathSeparator).last;

String formatFileSize(File file) {
  final bytes = file.lengthSync();
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
