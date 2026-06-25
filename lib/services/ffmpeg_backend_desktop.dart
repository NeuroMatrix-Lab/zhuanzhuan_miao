import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/format_info.dart';
import 'ffmpeg_backend_interface.dart';

class FFmpegBackendDesktop implements FFmpegBackend {
  String _ffmpegPath = 'ffmpeg';

  @override
  Future<String> findPath() async {
    String exeDir = path.dirname(Platform.resolvedExecutable);
    String appDir = Directory.current.path;

    developer.log('Executable directory: $exeDir', name: 'FFmpegBackendDesktop');
    developer.log('Current working directory: $appDir', name: 'FFmpegBackendDesktop');

    List<String> possiblePaths = [
      path.join(exeDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, '..', 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, '..', '..', 'resources', 'windows', 'ffmpeg.exe'),
      'resources/windows/ffmpeg.exe',
      'ffmpeg.exe',
    ];

    for (String p in possiblePaths) {
      try {
        File file = File(p);
        if (await file.exists()) {
          _ffmpegPath = p;
          developer.log('Found FFmpeg at: $p', name: 'FFmpegBackendDesktop');
          return p;
        }
      } catch (e) {
        developer.log('Error checking path $p: $e', name: 'FFmpegBackendDesktop');
      }
    }

    try {
      ProcessResult result = await Process.run('where', ['ffmpeg'], runInShell: true);
      if (result.exitCode == 0 && result.stdout.isNotEmpty) {
        _ffmpegPath = (result.stdout as String).trim().split('\n').first;
        developer.log('Found FFmpeg in PATH: $_ffmpegPath', name: 'FFmpegBackendDesktop');
        return _ffmpegPath;
      }
    } catch (e) {
      developer.log('Error checking PATH: $e', name: 'FFmpegBackendDesktop');
    }

    return 'ffmpeg';
  }

  @override
  Future<double> getDuration(String inputPath) async {
    String ffmpegPath = await findPath();
    try {
      ProcessResult result = await Process.run(ffmpegPath, ['-i', inputPath], runInShell: true);
      String output = (result.stderr as String);
      RegExp durationRegex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)');
      Match? match = durationRegex.firstMatch(output);
      if (match != null) {
        int hours = int.parse(match.group(1)!);
        int minutes = int.parse(match.group(2)!);
        int seconds = int.parse(match.group(3)!);
        int centiseconds = int.parse(match.group(4)!);
        return hours * 3600 + minutes * 60 + seconds + centiseconds / 100.0;
      }
    } catch (e) {
      developer.log('Error detecting duration: $e', name: 'FFmpegBackendDesktop');
    }
    return 0;
  }

  @override
  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    List<HardwareAccelerator> accelerators = [HardwareAccelerator(id: 'cpu', name: 'CPU', available: true)];
    try {
      String ffmpegPath = await findPath();
      ProcessResult result = await Process.run(ffmpegPath, ['-hide_banner', '-encoders'], runInShell: true);
      if (result.exitCode == 0) {
        String encoders = (result.stdout as String).toLowerCase();
        if (encoders.contains('nvenc')) accelerators.insert(0, HardwareAccelerator(id: 'nvidia', name: 'NVIDIA NVENC', available: true));
        if (encoders.contains('amf')) accelerators.insert(0, HardwareAccelerator(id: 'amd', name: 'AMD VCE', available: true));
        if (encoders.contains('qsv')) accelerators.insert(0, HardwareAccelerator(id: 'intel', name: 'Intel QSV', available: true));
      }
    } catch (e) {
      developer.log('Error detecting hardware: $e', name: 'FFmpegBackendDesktop');
    }
    return accelerators;
  }

  @override
  Future<String> convert(String inputPath, String outputPath, String outputFormat, ConversionSettings settings, void Function(double progress) onProgress, String hardwareDevice) async {
    String ffmpegPath = await findPath();
    double totalDuration = await getDuration(inputPath);

    File inputFile = File(inputPath);
    if (!await inputFile.exists()) throw Exception('输入文件不存在: $inputPath');

    String outputDir = path.dirname(outputPath);
    if (!await Directory(outputDir).exists()) await Directory(outputDir).create(recursive: true);

    List<String> args = [];
    String hwAccel = '';
    String codec = 'libx264';

    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      switch (hardwareDevice) {
        case 'nvidia': hwAccel = 'cuda'; codec = 'h264_nvenc'; break;
        case 'amd': hwAccel = 'd3d11va'; codec = 'h264_amf'; break;
        case 'intel': hwAccel = 'qsv'; codec = 'h264_qsv'; break;
      }
    }
    if (hwAccel.isNotEmpty) args.addAll(['-hwaccel', hwAccel]);
    args.addAll(['-i', inputPath, '-y', '-progress', 'pipe:1', '-nostats']);

    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      args.addAll(['-c:v', codec]);
    } else {
      if (settings.videoBitrate == -1) {
        args.addAll(['-c:v', 'copy']);
      } else {
        args.addAll(['-c:v', 'lib${settings.videoCodec}']);
        if (settings.videoBitrate == 0) {
          if (settings.videoCodec == 'h264') {
            args.addAll(['-preset', 'medium', '-crf', '23']);
          } else if (settings.videoCodec == 'h265') {
            args.addAll(['-preset', 'medium', '-crf', '28']);
          }
        } else {
          args.addAll(['-b:v', '${settings.videoBitrate}k']);
        }
        if (settings.framerate > 0) args.addAll(['-r', '${settings.framerate}']);
        if (settings.resolutionWidth > 0 && settings.resolutionHeight > 0) args.addAll(['-vf', 'scale=${settings.resolutionWidth}:${settings.resolutionHeight}']);
      }
    }

    if (settings.audioBitrate == -1) {
      args.addAll(['-c:a', 'copy']);
    } else {
      String audioCodec = settings.audioCodec == 'mp3' ? 'libmp3lame' : settings.audioCodec;
      args.addAll(['-c:a', audioCodec]);
      if (settings.audioBitrate > 0) args.addAll(['-b:a', '${settings.audioBitrate}k']);
    }
    args.add(outputPath);

    Process process = await Process.start(ffmpegPath, args, runInShell: true);
    process.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
      if (line.startsWith('out_time_ms=') || line.startsWith('out_time_us=')) {
        try {
          double us = double.parse(line.split('=').last);
          double progress = totalDuration > 0 ? (us / 1000000.0 / totalDuration * 100).clamp(0, 99) : 0;
          onProgress(progress);
        } catch (e) {
          developer.log('Error parsing progress: $e', name: 'FFmpegBackendDesktop');
        }
      }
    });
    process.stderr.transform(utf8.decoder).listen((error) {
      developer.log('FFmpeg error: $error', name: 'FFmpegBackendDesktop');
    });

    int exitCode = await process.exitCode;
    if (exitCode == 0) { onProgress(100.0); return outputPath; }
    throw Exception('FFmpeg exited with code $exitCode');
  }

  @override
  Future<String> getVersion() async {
    try {
      String ffmpegPath = await findPath();
      ProcessResult result = await Process.run(ffmpegPath, ['-version'], runInShell: true);
      if (result.exitCode == 0) return (result.stdout as String).split('\n').first;
    } catch (e) {
      developer.log('Error getting version: $e', name: 'FFmpegBackendDesktop');
    }
    return 'FFmpeg not found';
  }
}
