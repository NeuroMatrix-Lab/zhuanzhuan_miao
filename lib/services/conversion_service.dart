import '../models/format_info.dart';

class ConversionService {
  static const List<FormatInfo> formats = [
    FormatInfo(format: 'mp4', name: 'MP4', isVideo: true),
    FormatInfo(format: 'avi', name: 'AVI', isVideo: true),
    FormatInfo(format: 'mkv', name: 'MKV', isVideo: true),
    FormatInfo(format: 'webm', name: 'WebM', isVideo: true),
    FormatInfo(format: 'mov', name: 'MOV', isVideo: true),
    FormatInfo(format: 'gif', name: 'GIF', isVideo: true),
    FormatInfo(format: 'jpg', name: 'JPEG', isVideo: true),
    FormatInfo(format: 'png', name: 'PNG', isVideo: true),
    FormatInfo(format: 'mp3', name: 'MP3', isVideo: false),
    FormatInfo(format: 'wav', name: 'WAV', isVideo: false),
    FormatInfo(format: 'aac', name: 'AAC', isVideo: false),
    FormatInfo(format: 'flac', name: 'FLAC', isVideo: false),
    FormatInfo(format: 'ogg', name: 'OGG', isVideo: false),
  ];
}
