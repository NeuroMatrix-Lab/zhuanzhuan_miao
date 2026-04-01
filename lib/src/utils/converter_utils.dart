class ConverterUtils {
  static Map<String, String> getVideoFormats() {
    return {
      'mp4': 'MP4',
      'mkv': 'MKV',
      'avi': 'AVI',
      'mov': 'MOV',
      'wmv': 'WMV',
      'flv': 'FLV',
      'webm': 'WebM',
    };
  }

  static Map<String, String> getAudioFormats() {
    return {
      'mp3': 'MP3',
      'wav': 'WAV',
      'aac': 'AAC',
      'flac': 'FLAC',
      'ogg': 'OGG',
      'm4a': 'M4A',
    };
  }

  static bool isVideoFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return getVideoFormats().containsKey(extension);
  }

  static bool isAudioFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return getAudioFormats().containsKey(extension);
  }

  static String generateConversionCommand(String inputPath, String outputPath, {
    String? videoCodec,
    String? audioCodec,
    int? videoBitrate,
    int? audioBitrate,
    int? width,
    int? height,
  }) {
    List<String> args = ['-i', inputPath];

    if (videoCodec != null) {
      args.addAll(['-c:v', videoCodec]);
    }

    if (audioCodec != null) {
      args.addAll(['-c:a', audioCodec]);
    }

    if (videoBitrate != null) {
      args.addAll(['-b:v', '$videoBitrate']);
    }

    if (audioBitrate != null) {
      args.addAll(['-b:a', '$audioBitrate']);
    }

    if (width != null && height != null) {
      args.addAll(['-s', '${width}x$height']);
    }

    args.add(outputPath);

    return args.join(' ');
  }

  static String getDefaultVideoCodec(String outputFormat) {
    switch (outputFormat.toLowerCase()) {
      case 'mp4':
        return 'libx264';
      case 'mkv':
        return 'libx264';
      case 'avi':
        return 'mpeg4';
      case 'mov':
        return 'libx264';
      case 'wmv':
        return 'wmv2';
      case 'flv':
        return 'flv';
      case 'webm':
        return 'libvpx';
      default:
        return 'libx264';
    }
  }

  static String getDefaultAudioCodec(String outputFormat) {
    switch (outputFormat.toLowerCase()) {
      case 'mp3':
        return 'libmp3lame';
      case 'wav':
        return 'pcm_s16le';
      case 'aac':
        return 'aac';
      case 'flac':
        return 'flac';
      case 'ogg':
        return 'libvorbis';
      case 'm4a':
        return 'aac';
      default:
        return 'aac';
    }
  }
}
