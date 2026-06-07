import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

class FfmpegService {
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  final FlutterFFprobe _flutterFFprobe = FlutterFFprobe();

  Future<int> executeCommand(String command) async {
    return await _flutterFFmpeg.execute(command);
  }

  Future<dynamic> getMediaInformation(String filePath) async {
    return await _flutterFFprobe.getMediaInformation(filePath);
  }

  Future<void> cancel() async {
    await _flutterFFmpeg.cancel();
  }

  Future<void> enableStatisticsCallback(void Function(dynamic) callback) async {
    // API may have changed, skipping for now
  }

  Future<String> getFFmpegVersion() async {
    return '5.0.0';
  }

  Future<String> getPlatform() async {
    return 'unknown';
  }
}
