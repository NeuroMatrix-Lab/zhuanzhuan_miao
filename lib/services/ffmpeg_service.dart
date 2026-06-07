import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/format_info.dart';

class HardwareAccelerator {
  final String id;
  final String name;
  final bool available;

  HardwareAccelerator({
    required this.id,
    required this.name,
    required this.available,
  });
}

class FfmpegService {
  static FfmpegService? _instance;
  
  factory FfmpegService() {
    _instance ??= FfmpegService._internal();
    return _instance!;
  }
  
  FfmpegService._internal();

  String _ffmpegPath = 'ffmpeg';
  
  Future<String> _findFfmpegPath() async {
    // 获取应用运行目录
    String appDir = Directory.current.path;
    
    // 1. 检查应用资源目录（构建时打包的 FFmpeg）
    List<String> possiblePaths = [
      path.join(appDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, '..', 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, 'ffmpeg.exe'),
      'resources/windows/ffmpeg.exe',
      '../resources/windows/ffmpeg.exe',
      'ffmpeg.exe',
      'ffmpeg',
    ];
    
    for (String p in possiblePaths) {
      if (await File(p).exists()) {
        _ffmpegPath = p;
        developer.log('Found FFmpeg at: $p', name: 'FfmpegService');
        return p;
      }
    }
    
    // 2. 检查系统 PATH
    try {
      ProcessResult result = await Process.run('where', ['ffmpeg'], runInShell: true);
      if (result.exitCode == 0 && result.stdout.isNotEmpty) {
        _ffmpegPath = (result.stdout as String).trim().split('\n').first;
        developer.log('Found FFmpeg in PATH: $_ffmpegPath', name: 'FfmpegService');
        return _ffmpegPath;
      }
    } catch (_) {}
    
    // 3. 直接返回 ffmpeg（希望在 PATH 中）
    return 'ffmpeg';
  }

  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    List<HardwareAccelerator> accelerators = [
      HardwareAccelerator(id: 'cpu', name: 'CPU', available: true),
    ];
    
    try {
      String ffmpegPath = await _findFfmpegPath();
      ProcessResult result = await Process.run(
        ffmpegPath,
        ['-hide_banner', '-codecs'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        String codecs = (result.stdout as String).toLowerCase();
        
        if (codecs.contains('nvenc')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'nvidia',
            name: 'NVIDIA NVENC',
            available: true,
          ));
        }
        if (codecs.contains('vc_enc') || codecs.contains('amf')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'amd',
            name: 'AMD VCE',
            available: true,
          ));
        }
        if (codecs.contains('qsv')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'intel',
            name: 'Intel QSV',
            available: true,
          ));
        }
      }
    } catch (e) {
      // FFmpeg not found, only CPU available
    }
    
    return accelerators;
  }

  Future<String> convert(
    String inputPath,
    String outputPath,
    String outputFormat,
    ConversionSettings settings,
    void Function(double progress) onProgress,
    String hardwareDevice,
  ) async {
    String ffmpegPath = await _findFfmpegPath();
    
    List<String> args = [
      '-i', inputPath,
      '-y',
      '-progress', 'pipe:1',
      '-nostats',
    ];

    // 硬件加速
    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      String hwAccel = '';
      String codec = settings.videoCodec;
      
      switch (hardwareDevice) {
        case 'nvidia':
          hwAccel = 'cuda';
          codec = 'h264_nvenc';
          break;
        case 'amd':
          hwAccel = 'd3d11va';
          codec = 'h264_amf';
          break;
        case 'intel':
          hwAccel = 'qsv';
          codec = 'h264_qsv';
          break;
      }
      
      if (hwAccel.isNotEmpty) {
        args.addAll(['-hwaccel', hwAccel]);
      }
      args.addAll(['-c:v', codec]);
    } else {
      // 视频设置
      if (settings.videoBitrate == -1) {
        // 复制视频流
        args.addAll(['-c:v', 'copy']);
      } else {
        String codec = 'lib${settings.videoCodec}';
        args.addAll(['-c:v', codec]);
        
        if (settings.videoBitrate == 0) {
          // VBR
          if (settings.videoCodec == 'h264') {
            args.addAll(['-preset', 'medium', '-crf', '23']);
          } else if (settings.videoCodec == 'h265') {
            args.addAll(['-preset', 'medium', '-crf', '28']);
          }
        } else {
          // 固定码率
          args.addAll(['-b:v', '${settings.videoBitrate}k']);
        }
        
        // 帧率
        if (settings.framerate > 0) {
          args.addAll(['-r', '${settings.framerate}']);
        }
        
        // 分辨率
        if (settings.resolutionWidth > 0 && settings.resolutionHeight > 0) {
          args.addAll(['-vf', 'scale=${settings.resolutionWidth}:${settings.resolutionHeight}']);
        }
      }
    }

    // 音频设置
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

    args.add(outputPath);

    developer.log('FFmpeg command: $ffmpegPath ${args.join(' ')}', name: 'FfmpegService');

    Process process = await Process.start(
      ffmpegPath,
      args,
      runInShell: true,
    );

    // 监听进度
    Stream<String> progressStream = process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter());
    
    progressStream.listen((line) {
      if (line.startsWith('out_time_ms=')) {
        try {
          double ms = double.parse(line.split('=').last);
          double progress = (ms / 1000000.0 / 60.0 * 100).clamp(0, 99);
          onProgress(progress);
        } catch (_) {}
      }
    });

    // 监听错误
    process.stderr.transform(utf8.decoder).listen((error) {
      developer.log('FFmpeg error: $error', name: 'FfmpegService');
    });

    int exitCode = await process.exitCode;
    
    if (exitCode == 0) {
      onProgress(100.0);
      return outputPath;
    } else {
      throw Exception('FFmpeg exited with code $exitCode');
    }
  }

  Future<String> getVersion() async {
    try {
      String ffmpegPath = await _findFfmpegPath();
      ProcessResult result = await Process.run(
        ffmpegPath,
        ['-version'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        String output = result.stdout as String;
        return output.split('\n').first;
      }
    } catch (e) {
      developer.log('Error getting FFmpeg version: $e', name: 'FfmpegService');
    }
    return 'FFmpeg not found';
  }
}
