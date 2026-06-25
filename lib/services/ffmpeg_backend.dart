import 'dart:async';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/format_info.dart';
import 'ffmpeg_backend_interface.dart';

export 'ffmpeg_backend_interface.dart' show HardwareAccelerator;

class FFmpegBackendImpl implements FFmpegBackend {
  @override
  Future<String> findPath() async => 'ffmpeg';

  @override
  Future<double> getDuration(String inputPath) async {
    final session = await FFmpegKit.execute('-i "$inputPath"');
    final output = await session.getAllLogsAsString();
    final durationRegex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)');
    final match = durationRegex.firstMatch(output ?? '');
    if (match != null) {
      int hours = int.parse(match.group(1)!);
      int minutes = int.parse(match.group(2)!);
      int seconds = int.parse(match.group(3)!);
      int centiseconds = int.parse(match.group(4)!);
      return hours * 3600 + minutes * 60 + seconds + centiseconds / 100.0;
    }
    return 0;
  }

  @override
  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    return [HardwareAccelerator(id: 'cpu', name: 'CPU', available: true)];
  }

  @override
  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  ) async {
    List<String> args = ['-i', '"$inputPath"', '-y'];

    if (settings.videoBitrate == -1) {
      args.addAll(['-c:v', 'copy']);
    } else {
      String codec = 'lib${settings.videoCodec}';
      args.addAll(['-c:v', codec]);
      if (settings.videoBitrate == 0) {
        if (settings.videoCodec == 'h264') {
          args.addAll(['-preset', 'medium', '-crf', '23']);
        } else if (settings.videoCodec == 'h265') {
          args.addAll(['-preset', 'medium', '-crf', '28']);
        }
      } else {
        args.addAll(['-b:v', '${settings.videoBitrate}k']);
      }
      if (settings.framerate > 0) {
        args.addAll(['-r', '${settings.framerate}']);
      }
      if (settings.resolutionWidth > 0 && settings.resolutionHeight > 0) {
        args.addAll(['-vf', 'scale=${settings.resolutionWidth}:${settings.resolutionHeight}']);
      }
    }

    if (settings.audioBitrate == -1) {
      args.addAll(['-c:a', 'copy']);
    } else {
      String codec = settings.audioCodec;
      if (codec == 'mp3') codec = 'libmp3lame';
      args.addAll(['-c:a', codec]);
      if (settings.audioBitrate > 0) {
        args.addAll(['-b:a', '${settings.audioBitrate}k']);
      }
    }

    args.add('"$outputPath"');

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress(100.0);
      return outputPath;
    } else {
      throw Exception('FFmpegKit conversion failed');
    }
  }

  @override
  Future<String> getVersion() async {
    final session = await FFmpegKit.execute('-version');
    final output = await session.getAllLogsAsString();
    return (output ?? '').split('\n').first;
  }
}
