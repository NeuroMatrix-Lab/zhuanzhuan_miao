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
    String exeDir = path.dirname(Platform.resolvedExecutable);
    String appDir = Directory.current.path;
    
    developer.log('Executable directory: $exeDir', name: 'FfmpegService');
    developer.log('Current working directory: $appDir', name: 'FfmpegService');
    
    String platform = Platform.operatingSystem;
    developer.log('Operating system: $platform', name: 'FfmpegService');
    
    String resourcesSubdir = platform == 'macos' ? 'macos' : 'windows';
    
    List<String> possiblePaths = [
      path.join(exeDir, 'resources', 'macos', 'ffmpeg'),
      path.join(exeDir, 'resources', 'macos', 'ffmpeg.exe'),
      path.join(exeDir, 'ffmpeg'),
      path.join(appDir, 'resources', 'macos', 'ffmpeg'),
      path.join(exeDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(exeDir, 'ffmpeg.exe'),
      path.join(appDir, 'resources', 'windows', 'ffmpeg.exe'),
      path.join(appDir, 'ffmpeg.exe'),
      path.join(appDir, '..', 'resources', resourcesSubdir, 'ffmpeg'),
      path.join(appDir, '..', 'resources', resourcesSubdir, 'ffmpeg.exe'),
      path.join(appDir, '..', '..', 'resources', resourcesSubdir, 'ffmpeg'),
      path.join(appDir, '..', '..', 'resources', resourcesSubdir, 'ffmpeg.exe'),
      'resources/macos/ffmpeg',
      'resources/windows/ffmpeg.exe',
      'ffmpeg',
    ];
    
    for (String p in possiblePaths) {
      try {
        File file = File(p);
        if (await file.exists()) {
          _ffmpegPath = p;
          developer.log('Found FFmpeg at: $p', name: 'FfmpegService');
          return p;
        }
      } catch (e) {
        developer.log('Error checking path $p: $e', name: 'FfmpegService');
      }
    }
    
    try {
      ProcessResult result = await Process.run('which', ['ffmpeg'], runInShell: true);
      if (result.exitCode == 0 && result.stdout.isNotEmpty) {
        _ffmpegPath = (result.stdout as String).trim().split('\n').first;
        developer.log('Found FFmpeg in PATH: $_ffmpegPath', name: 'FfmpegService');
        return _ffmpegPath;
      }
    } catch (e) {
      developer.log('Error checking PATH: $e', name: 'FfmpegService');
    }
    
    developer.log('FFmpeg not found in known locations, trying system ffmpeg', name: 'FfmpegService');
    return 'ffmpeg';
  }

  Future<double> _getDuration(String inputPath) async {
    String ffmpegPath = await _findFfmpegPath();
    try {
      ProcessResult result = await Process.run(
        ffmpegPath,
        ['-i', inputPath],
        runInShell: true,
      );
      String output = (result.stderr as String);
      RegExp durationRegex = RegExp(r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)');
      Match? match = durationRegex.firstMatch(output);
      if (match != null) {
        int hours = int.parse(match.group(1)!);
        int minutes = int.parse(match.group(2)!);
        int seconds = int.parse(match.group(3)!);
        int centiseconds = int.parse(match.group(4)!);
        double duration = hours * 3600 + minutes * 60 + seconds + centiseconds / 100.0;
        developer.log('Detected duration: ${duration}s', name: 'FfmpegService');
        return duration;
      }
    } catch (e) {
      developer.log('Error detecting duration: $e', name: 'FfmpegService');
    }
    return 0;
  }

  Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    List<HardwareAccelerator> accelerators = [
      HardwareAccelerator(id: 'cpu', name: 'CPU', available: true),
    ];
    
    try {
      String ffmpegPath = await _findFfmpegPath();
      String platform = Platform.operatingSystem;
      developer.log('Detecting hardware accelerators using: $ffmpegPath on $platform', name: 'FfmpegService');
      
      ProcessResult result = await Process.run(
        ffmpegPath,
        ['-hide_banner', '-encoders'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        String encoders = (result.stdout as String).toLowerCase();
        
        if (platform == 'macos') {
          if (encoders.contains('videotoolbox') || encoders.contains('h264_videotoolbox') || encoders.contains('hevc_videotoolbox')) {
            accelerators.insert(0, HardwareAccelerator(
              id: 'apple',
              name: 'Apple VideoToolbox',
              available: true,
            ));
            developer.log('Detected Apple VideoToolbox', name: 'FfmpegService');
          }
        } else {
          if (encoders.contains('nvenc') || encoders.contains('h264_nvenc') || encoders.contains('hevc_nvenc')) {
            accelerators.insert(0, HardwareAccelerator(
              id: 'nvidia',
              name: 'NVIDIA NVENC',
              available: true,
            ));
            developer.log('Detected NVIDIA NVENC', name: 'FfmpegService');
          }

          if (encoders.contains('amf') || encoders.contains('h264_amf') || encoders.contains('hevc_amf')) {
            accelerators.insert(0, HardwareAccelerator(
              id: 'amd',
              name: 'AMD VCE',
              available: true,
            ));
            developer.log('Detected AMD VCE', name: 'FfmpegService');
          }

          if (encoders.contains('qsv') || encoders.contains('h264_qsv') || encoders.contains('hevc_qsv')) {
            accelerators.insert(0, HardwareAccelerator(
              id: 'intel',
              name: 'Intel QSV',
              available: true,
            ));
            developer.log('Detected Intel QSV', name: 'FfmpegService');
          }
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

    double totalDuration = await _getDuration(inputPath);
    developer.log('Total duration: ${totalDuration}s', name: 'FfmpegService');

    File inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('输入文件不存在: $inputPath');
    }
    
    String outputDir = path.dirname(outputPath);
    Directory dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    List<String> args = [];

    String codec = 'libx264';
    String hwAccel = '';
    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      String platform = Platform.operatingSystem;
      
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
        case 'apple':
          codec = 'h264_videotoolbox';
          break;
      }
      developer.log('Using hardware acceleration: $hardwareDevice on $platform, codec: $codec', name: 'FfmpegService');
    }

    if (hwAccel.isNotEmpty) {
      args.addAll(['-hwaccel', hwAccel]);
    }

    args.addAll([
      '-i', inputPath,
      '-y',
      '-progress', 'pipe:1',
      '-nostats',
    ]);

    if (settings.hardwareAcceleration && hardwareDevice != 'cpu') {
      args.addAll(['-c:v', codec]);
    } else {
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

    args.add(outputPath);

    developer.log('FFmpeg command: $ffmpegPath ${args.join(' ')}', name: 'FfmpegService');

    Process process = await Process.start(
      ffmpegPath,
      args,
      runInShell: true,
    );

    Stream<String> progressStream = process.stdout
        .transform(utf8.decoder)
        .transform(LineSplitter());

    progressStream.listen((line) {
      if (line.startsWith('out_time_ms=') || line.startsWith('out_time_us=')) {
        try {
          double us = double.parse(line.split('=').last);
          double currentSeconds = us / 1000000.0;
          double progress = totalDuration > 0
              ? (currentSeconds / totalDuration * 100).clamp(0, 99)
              : 0;
          onProgress(progress);
        } catch (e) {
          developer.log('Error parsing progress: $e', name: 'FfmpegService');
        }
      }
      if (line.startsWith('out_time=')) {
        try {
          String timeStr = line.split('=').last.trim();
          RegExp timeRegex = RegExp(r'(\d+):(\d+):(\d+)\.(\d+)');
          Match? match = timeRegex.firstMatch(timeStr);
          if (match != null && totalDuration > 0) {
            int hours = int.parse(match.group(1)!);
            int minutes = int.parse(match.group(2)!);
            int seconds = int.parse(match.group(3)!);
            int frac = int.parse(match.group(4)!);
            double currentSeconds = hours * 3600 + minutes * 60 + seconds + frac / 100.0;
            double progress = (currentSeconds / totalDuration * 100).clamp(0, 99);
            onProgress(progress);
          }
        } catch (e) {
          developer.log('Error parsing out_time: $e', name: 'FfmpegService');
        }
      }
    });

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
