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
    await _flutterFFmpeg.enableStatisticsCallback(callback);
  }

  Future<String> getFFmpegVersion() async {
    return await _flutterFFmpeg.getVersion();
  }

  Future<String> getPlatform() async {
    return await _flutterFFmpeg.getPlatform();
  }
}
