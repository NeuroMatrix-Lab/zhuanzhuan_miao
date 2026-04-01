import 'dart:io';
import './ffmpeg_service.dart';
import './file_service.dart';
import './log_service.dart';
import '../utils/converter_utils.dart';

class ConversionService {
  final FfmpegService _ffmpegService;
  final FileService _fileService;
  final LogService _logService = LogService();

  ConversionService(this._ffmpegService, this._fileService);

  Future<File> convertFile(
    File inputFile,
    String outputFormat,
    {
      String? videoCodec,
      String? audioCodec,
      int? videoBitrate,
      int? audioBitrate,
      int? width,
      int? height,
      Function(double)? onProgress,
    }
  ) async {
    try {
      await _logService.info('Starting conversion: ${inputFile.path} to $outputFormat');
      
      final outputDir = await _fileService.getOutputDirectory();
      final outputFileName = _fileService.getOutputPath(inputFile.path, outputFormat);
      final outputPath = '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      String codecVideo = videoCodec ?? 
        (ConverterUtils.isVideoFile(inputFile.path) 
          ? ConverterUtils.getDefaultVideoCodec(outputFormat) 
          : 'copy');
      
      String codecAudio = audioCodec ?? 
        (ConverterUtils.isAudioFile(inputFile.path) 
          ? ConverterUtils.getDefaultAudioCodec(outputFormat) 
          : 'copy');

      final command = ConverterUtils.generateConversionCommand(
        inputFile.path,
        outputPath,
        videoCodec: codecVideo,
        audioCodec: codecAudio,
        videoBitrate: videoBitrate,
        audioBitrate: audioBitrate,
        width: width,
        height: height,
      );

      await _logService.debug('Executing command: $command');

      if (onProgress != null) {
        _ffmpegService.enableStatisticsCallback((statistics) {
          final progress = statistics['progress'] ?? 0;
          onProgress(progress);
        });
      }

      final stopwatch = Stopwatch()..start();
      final result = await _ffmpegService.executeCommand(command);
      stopwatch.stop();

      await _logService.info('Conversion completed in ${stopwatch.elapsedMilliseconds}ms with code: $result');

      if (result != 0) {
        await _logService.error('Conversion failed', 'Exit code: $result');
        throw Exception('Conversion failed with code: $result');
      }

      await _logService.info('Output file: $outputPath');
      return File(outputPath);
    } catch (e) {
      await _logService.error('Error during conversion', e);
      rethrow;
    }
  }

  Future<List<File>> batchConvertFiles(
    List<File> inputFiles,
    String outputFormat,
    {
      String? videoCodec,
      String? audioCodec,
      int? videoBitrate,
      int? audioBitrate,
      int? width,
      int? height,
      Function(int, double)? onProgress,
    }
  ) async {
    final outputFiles = <File>[];
    await _logService.info('Starting batch conversion of ${inputFiles.length} files to $outputFormat');

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < inputFiles.length; i++) {
      final inputFile = inputFiles[i];
      try {
        await _logService.info('Processing file $i/${inputFiles.length}: ${inputFile.path}');
        final outputFile = await convertFile(
          inputFile,
          outputFormat,
          videoCodec: videoCodec,
          audioCodec: audioCodec,
          videoBitrate: videoBitrate,
          audioBitrate: audioBitrate,
          width: width,
          height: height,
          onProgress: (progress) {
            if (onProgress != null) {
              onProgress(i, progress);
            }
          },
        );
        outputFiles.add(outputFile);
        await _logService.info('Successfully converted file $i/${inputFiles.length}');
      } catch (e) {
        await _logService.error('Error converting ${inputFile.path}', e);
      }
    }

    stopwatch.stop();
    await _logService.info('Batch conversion completed in ${stopwatch.elapsedMilliseconds}ms. Converted ${outputFiles.length}/${inputFiles.length} files');

    return outputFiles;
  }

  Future<dynamic> getMediaInfo(File file) async {
    try {
      await _logService.info('Getting media information for: ${file.path}');
      final info = await _ffmpegService.getMediaInformation(file.path);
      await _logService.debug('Media info: $info');
      return info;
    } catch (e) {
      await _logService.error('Error getting media information', e);
      throw Exception('Failed to get media information: $e');
    }
  }
}
