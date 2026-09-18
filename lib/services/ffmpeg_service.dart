import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';

import '../models/format_info.dart';

class HardwareAccelerator {
  final String id;
  final String name;

  const HardwareAccelerator({required this.id, required this.name});
}

/// 全平台统一 ffmpeg_kit_flutter_new
class FfmpegService {
  FfmpegService._();

  static const _audioOnly = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'};
  static const _images = {'jpg', 'jpeg', 'png'};

  static Future<List<HardwareAccelerator>> detectHardwareAccelerators() async {
    final list = <HardwareAccelerator>[
      const HardwareAccelerator(id: 'cpu', name: 'CPU'),
    ];

    try {
      final session = await FFmpegKit.execute('-hide_banner -encoders');
      final out = ((await session.getAllLogsAsString()) ?? '').toLowerCase();

      void add(String token, String id, String name) {
        if (out.contains(token)) {
          list.insert(0, HardwareAccelerator(id: id, name: name));
        }
      }

      add('videotoolbox', 'apple', 'Apple VideoToolbox');
      add('nvenc', 'nvidia', 'NVIDIA NVENC');
      add('amf', 'amd', 'AMD VCE');
      add('qsv', 'intel', 'Intel QSV');
    } catch (_) {}

    return list;
  }

  static Future<String> convert(
    String inputPath,
    String outputPath,
    ConversionSettings settings,
    void Function(double) onProgress,
    String hardwareDevice,
  ) async {
    if (!await File(inputPath).exists()) {
      throw Exception('输入文件不存在: $inputPath');
    }

    final outDir = Directory(outputPath).parent;
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final duration = await _duration(inputPath);
    final args = _buildArgs(inputPath, outputPath, settings, hardwareDevice);

    FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
      if (duration <= 0) return;
      onProgress((stats.getTime() / 1000 / duration * 100).clamp(0.0, 99.0));
    });

    final session = await FFmpegKit.executeWithArguments(args);
    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      onProgress(100);
      return outputPath;
    }

    final logs = await session.getAllLogsAsString();
    final tail = (logs ?? '')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(8)
        .join(' | ');
    throw Exception('FFmpeg 转换失败${tail.isEmpty ? '' : ': $tail'}');
  }

  static Future<double> _duration(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      return double.tryParse(session.getMediaInformation()?.getDuration() ?? '') ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static List<String> _buildArgs(
    String input,
    String output,
    ConversionSettings s,
    String hw,
  ) {
    final format = output.split('.').last.toLowerCase();
    final args = <String>['-y', '-i', input];

    if (_audioOnly.contains(format)) {
      args.add('-vn');
      args.addAll(_audioArgs(s));
    } else if (_images.contains(format)) {
      args.addAll([
        '-frames:v', '1',
        '-c:v', format == 'png' ? 'png' : 'mjpeg',
        '-f', 'image2',
        '-an',
      ]);
    } else if (format == 'gif') {
      args.addAll(['-c:v', 'gif', '-an']);
      if (s.resolutionWidth > 0 && s.resolutionHeight > 0) {
        args.addAll(['-vf', _scaleFilter(s)]);
      }
    } else {
      args.addAll(_videoArgs(s, hw));
      args.addAll(_audioArgs(s));
    }

    return [...args, output];
  }

  static List<String> _videoArgs(ConversionSettings s, String hw) {
    if (s.videoBitrate == ConversionSettings.bitrateCopy) {
      return ['-c:v', 'copy'];
    }

    final args = <String>['-c:v', _videoEncoder(s, hw)];
    final useHw = s.hardwareAcceleration && hw != 'cpu';

    if (s.videoBitrate == ConversionSettings.bitrateVBR) {
      if (!useHw) {
        args.addAll(['-preset', 'medium', '-crf', s.videoCodec == 'h265' ? '28' : '23']);
      }
    } else if (s.videoBitrate > 0) {
      args.addAll(['-b:v', '${s.videoBitrate}k']);
    }

    if (s.framerate > 0) args.addAll(['-r', '${s.framerate}']);
    if (s.resolutionWidth > 0 && s.resolutionHeight > 0) {
      args.addAll(['-vf', _scaleFilter(s)]);
    }
    return args;
  }

  static List<String> _audioArgs(ConversionSettings s) {
    if (s.audioBitrate == ConversionSettings.bitrateCopy) {
      return ['-c:a', 'copy'];
    }
    final args = <String>[
      '-c:a',
      s.audioCodec == 'mp3' ? 'libmp3lame' : s.audioCodec,
    ];
    if (s.audioBitrate > 0) args.addAll(['-b:a', '${s.audioBitrate}k']);
    if (s.sampleRate > 0) args.addAll(['-ar', '${s.sampleRate}']);
    return args;
  }

  static String _scaleFilter(ConversionSettings s) =>
      'scale=${s.resolutionWidth}:${s.resolutionHeight}';

  static String _videoEncoder(ConversionSettings s, String hw) {
    final hevc = s.videoCodec == 'h265';

    if (s.hardwareAcceleration && hw != 'cpu') {
      switch (hw) {
        case 'nvidia':
          return hevc ? 'hevc_nvenc' : 'h264_nvenc';
        case 'amd':
          return hevc ? 'hevc_amf' : 'h264_amf';
        case 'intel':
          return hevc ? 'hevc_qsv' : 'h264_qsv';
        case 'apple':
          return hevc ? 'hevc_videotoolbox' : 'h264_videotoolbox';
      }
    }

    switch (s.videoCodec) {
      case 'h265':
        return 'libx265';
      case 'vp9':
        return 'libvpx-vp9';
      case 'av1':
        return 'libaom-av1';
      default:
        return 'libx264';
    }
  }
}
