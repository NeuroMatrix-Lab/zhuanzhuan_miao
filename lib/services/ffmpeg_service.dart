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
    developer.log('App directory: $appDir', name: 'FfmpegService');
    
    // 1. 检查应用资源目录（构建时打包的 FFmpeg）
    List<String> possiblePaths = [
      path.join(appDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, 'ffmpeg.exe'),
      path.join(path.dirname(Platform.resolvedExecutable), 'resources', 'windows', 'ffmpeg.exe'),
      path.join(path.dirname(Platform.resolvedExecutable), 'ffmpeg.exe'),
      'resources/windows/ffmpeg.exe',
      'ffmpeg.exe',
      'ffmpeg',
    ];
    
    for (String p in possiblePaths) {
      File file = File(p);
      if (await file.exists()) {
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
    } catch (e) {
      developer.log('Error checking PATH: $e', name: 'FfmpegService');
    }
    
    // 3. 尝试直接调用（希望在 PATH 中）
    developer.log('FFmpeg not found in known locations, using system ffmpeg', name: 'FfmpegService');
    return 'ffmpeg';
  }

  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    List<HardwareAccelerator> accelerators = [
      HardwareAccelerator(id: 'cpu', name: 'CPU', available: true),
    ];
    
    try {
      String ffmpegPath = await _findFfmpegPath();
      developer.log('Detecting hardware accelerators using: $ffmpegPath', name: 'FfmpegService');
      
      // 使用 -encoders 而不是 -codecs 来检测编码器
      ProcessResult result = await Process.run(
        ffmpegPath,
        ['-hide_banner', '-encoders'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        String encoders = (result.stdout as String).toLowerCase();
        developer.log('FFmpeg encoders output (first 500 chars): ${encoders.substring(0, encoders.length > 500 ? 500 : encoders.length)}', name: 'FfmpegService');
        
        // 检测 NVIDIA NVENC
        if (encoders.contains('nvenc') || encoders.contains('h264_nvenc') || encoders.contains('hevc_nvenc')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'nvidia',
            name: 'NVIDIA NVENC',
            available: true,
          ));
          developer.log('Detected NVIDIA NVENC', name: 'FfmpegService');
        }

        // 检测 AMD VCE/AMF
        if (encoders.contains('amf') || encoders.contains('h264_amf') || encoders.contains('hevc_amf')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'amd',
            name: 'AMD VCE',
            available: true,
          ));
          developer.log('Detected AMD VCE', name: 'FfmpegService');
        }

        // 检测 Intel QSV
        if (encoders.contains('qsv') || encoders.contains('h264_qsv') || encoders.contains('hevc_qsv')) {
          accelerators.insert(0, HardwareAccelerator(
            id: 'intel',
            name: 'Intel QSV',
            available: true,
          ));
          developer.log('Detected Intel QSV', name: 'FfmpegService');
        }
      } else {
        developer.log('FFmpeg encoders command failed with code: ${result.exitCode}', name: 'FfmpegService');
        if (result.stderr != null) {
          developer.log('FFmpeg error: ${result.stderr}', name: 'FfmpegService');
        }
      }
    } catch (e) {
      developer.log('Error detecting hardware accelerators: $e', name: 'FfmpegService');
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
    developer.log('Starting conversion with FFmpeg: $ffmpegPath', name: 'FfmpegService');
    
    List<String> args = [
      '-i', inputPath,
      '-y',
      '-progress', 'pipe:1',
      '-nostats',
    ];

    // 硬件加速
    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      String hwAccel = '';
      String codec = 'h264';
      
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
      developer.log('Using hardware acceleration: $hardwareDevice, codec: $codec', name: 'FfmpegService');
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
        } catch (e) {
          developer.log('Error parsing progress: $e', name: 'FfmpegService');
        }
      }
    });

    // 监听错误
    process.stderr.transform(utf8.decoder).listen((error) {
      developer.log('FFmpeg error: $error', name: 'FfmpegService');
    });

    int exitCode = await process.exitCode;
    developer.log('FFmpeg exit code: $exitCode', name: 'FfmpegService');
    
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
