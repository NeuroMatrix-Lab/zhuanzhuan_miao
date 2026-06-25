import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/format_info.dart';

class HardwareAccelerator {
  final String id;
  final String name;
  final bool available;
  HardwareAccelerator({required this.id, required this.name, required this.available});
}

class FfmpegService {
  static FfmpegService? _instance;
  String _ffmpegPath = '';

  factory FfmpegService() {
    _instance ??= FfmpegService._internal();
    return _instance!;
  }

  FfmpegService._internal();

  Future<String> _findFfmpeg() async {
    if (_ffmpegPath.isNotEmpty) return _ffmpegPath;

    String platform = Platform.operatingSystem;

    if (platform == 'android' || platform == 'ios') {
      return await _extractMobileFfmpeg();
    }

    String exeDir = path.dirname(Platform.resolvedExecutable);
    String appDir = Directory.current.path;
    String suffix = platform == 'windows' ? '.exe' : '';
    String sub = platform == 'macos' ? 'macos' : platform == 'linux' ? 'linux' : 'windows';

    List<String> candidates = [
      path.join(exeDir, 'resources', sub, 'ffmpeg$suffix'),
      path.join(appDir, 'resources', sub, 'ffmpeg$suffix'),
      path.join(appDir, '..', 'resources', sub, 'ffmpeg$suffix'),
      path.join(appDir, '..', '..', 'resources', sub, 'ffmpeg$suffix'),
      'resources/$sub/ffmpeg$suffix',
    ];

    for (String p in candidates) {
      if (await File(p).exists()) {
        _ffmpegPath = p;
        return p;
      }
    }

    try {
      String cmd = platform == 'windows' ? 'where' : 'which';
      var r = await Process.run(cmd, ['ffmpeg'], runInShell: true);
      if (r.exitCode == 0 && (r.stdout as String).isNotEmpty) {
        _ffmpegPath = (r.stdout as String).trim().split('\n').first;
        return _ffmpegPath;
      }
    } catch (_) {}

    return 'ffmpeg';
  }

  Future<String> _extractMobileFfmpeg() async {
    final appDir = await getApplicationDocumentsDirectory();
    final ffmpegFile = File(path.join(appDir.path, 'ffmpeg_bin', 'ffmpeg'));

    if (await ffmpegFile.exists()) {
      _ffmpegPath = ffmpegFile.path;
      return _ffmpegPath;
    }

    String assetPath = Platform.isAndroid ? 'assets/ffmpeg/android/ffmpeg' : 'assets/ffmpeg/ios/ffmpeg';
    final data = await rootBundle.load(assetPath);
    await ffmpegFile.parent.create(recursive: true);
    await ffmpegFile.writeAsBytes(data.buffer.asUint8List());

    if (Platform.isIOS) {
      await Process.run('chmod', ['+x', ffmpegFile.path]);
    }

    _ffmpegPath = ffmpegFile.path;
    return _ffmpegPath;
  }

  Future<double> _getDuration(String inputPath) async {
    String ffmpeg = await _findFfmpeg();
    try {
      var r = await Process.run(ffmpeg, ['-i', inputPath], runInShell: true);
      String stderr = r.stderr as String;
      var m = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)').firstMatch(stderr);
      if (m != null) {
        return int.parse(m.group(1)!) * 3600 +
            int.parse(m.group(2)!) * 60 +
            int.parse(m.group(3)!) +
            int.parse(m.group(4)!) / 100.0;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    List<HardwareAccelerator> list = [HardwareAccelerator(id: 'cpu', name: 'CPU', available: true)];
    if (Platform.isAndroid || Platform.isIOS) return list;

    try {
      String ffmpeg = await _findFfmpeg();
      var r = await Process.run(ffmpeg, ['-hide_banner', '-encoders'], runInShell: true);
      if (r.exitCode == 0) {
        String enc = (r.stdout as String).toLowerCase();
        if (enc.contains('nvenc')) list.insert(0, HardwareAccelerator(id: 'nvidia', name: 'NVIDIA NVENC', available: true));
        if (enc.contains('amf')) list.insert(0, HardwareAccelerator(id: 'amd', name: 'AMD VCE', available: true));
        if (enc.contains('qsv')) list.insert(0, HardwareAccelerator(id: 'intel', name: 'Intel QSV', available: true));
        if (enc.contains('videotoolbox')) list.insert(0, HardwareAccelerator(id: 'apple', name: 'Apple VideoToolbox', available: true));
      }
    } catch (_) {}
    return list;
  }

  Future<String> convert(
    String inputPath, String outputPath, String outputFormat,
    ConversionSettings settings, void Function(double) onProgress, String hardwareDevice,
  ) async {
    String ffmpeg = await _findFfmpeg();
    double totalDuration = await _getDuration(inputPath);

    if (!await File(inputPath).exists()) throw Exception('输入文件不存在: $inputPath');
    String outDir = path.dirname(outputPath);
    if (!await Directory(outDir).exists()) await Directory(outDir).create(recursive: true);

    List<String> args = [];
    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      String hw = '', codec = 'libx264';
      switch (hardwareDevice) {
        case 'nvidia': hw = 'cuda'; codec = 'h264_nvenc'; break;
        case 'amd': hw = 'd3d11va'; codec = 'h264_amf'; break;
        case 'intel': hw = 'qsv'; codec = 'h264_qsv'; break;
        case 'apple': codec = 'h264_videotoolbox'; break;
      }
      if (hw.isNotEmpty) args.addAll(['-hwaccel', hw]);
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
        if (settings.resolutionWidth > 0 && settings.resolutionHeight > 0) {
          args.addAll(['-vf', 'scale=${settings.resolutionWidth}:${settings.resolutionHeight}']);
        }
      }
    }

    if (settings.audioBitrate == -1) {
      args.addAll(['-c:a', 'copy']);
    } else {
      String ac = settings.audioCodec == 'mp3' ? 'libmp3lame' : settings.audioCodec;
      args.addAll(['-c:a', ac]);
      if (settings.audioBitrate > 0) args.addAll(['-b:a', '${settings.audioBitrate}k']);
    }

    args.addAll(['-i', inputPath, '-y', '-progress', 'pipe:1', '-nostats', outputPath]);

    Process proc = await Process.start(ffmpeg, args, runInShell: true);
    proc.stdout.transform(utf8.decoder).transform(LineSplitter()).listen((line) {
      if (line.startsWith('out_time_ms=') || line.startsWith('out_time_us=')) {
        try {
          double us = double.parse(line.split('=').last);
          double p = totalDuration > 0 ? (us / 1e6 / totalDuration * 100).clamp(0, 99) : 0;
          onProgress(p);
        } catch (_) {}
      }
    });

    int exitCode = await proc.exitCode;
    if (exitCode == 0) { onProgress(100); return outputPath; }
    throw Exception('FFmpeg exited with code $exitCode');
  }

  Future<String> getVersion() async {
    try {
      String ffmpeg = await _findFfmpeg();
      var r = await Process.run(ffmpeg, ['-version'], runInShell: true);
      if (r.exitCode == 0) return (r.stdout as String).split('\n').first;
    } catch (_) {}
    return 'FFmpeg not found';
  }
}
