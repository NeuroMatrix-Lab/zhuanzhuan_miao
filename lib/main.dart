import 'dart:io';
import 'package:flutter/material.dart';
import 'src/services/ffmpeg_service.dart';
import 'src/services/file_service.dart';
import 'src/services/conversion_service.dart';
import 'src/utils/converter_utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FFmpeg Converter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FfmpegService _ffmpegService = FfmpegService();
  final FileService _fileService = FileService();
  late ConversionService _conversionService;
  
  File? _selectedFile;
  List<File> _selectedFiles = [];
  String _outputFormat = 'mp4';
  double _progress = 0.0;
  bool _isConverting = false;
  String _status = 'Ready';
  final List<File> _convertedFiles = [];

  @override
  void initState() {
    super.initState();
    _conversionService = ConversionService(_ffmpegService, _fileService);
    _checkFFmpeg();
  }

  Future<void> _checkFFmpeg() async {
    try {
      final version = await _ffmpegService.getFFmpegVersion();
      final platform = await _ffmpegService.getPlatform();
      setState(() {
        _status = 'FFmpeg $version on $platform';
      });
    } catch (e) {
      setState(() {
        _status = 'FFmpeg error: $e';
      });
    }
  }

  Future<void> _selectFile() async {
    final file = await _fileService.pickFile();
    if (file != null) {
      setState(() {
        _selectedFile = file;
        _selectedFiles = [file];
        _status = 'Selected: ${_fileService.getFileName(file.path)}';
      });
    }
  }

  Future<void> _selectMultipleFiles() async {
    final files = await _fileService.pickMultipleFiles();
    if (files.isNotEmpty) {
      setState(() {
        _selectedFiles = files;
        _selectedFile = files.first;
        _status = 'Selected ${files.length} files';
      });
    }
  }

  Future<void> _convertFile() async {
    if (_selectedFile == null) {
      setState(() {
        _status = 'Please select a file first';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _status = 'Converting...';
    });

    try {
      if (_selectedFiles.length == 1) {
        // 单个文件转换
        final outputFile = await _conversionService.convertFile(
          _selectedFile!,
          _outputFormat,
          onProgress: (progress) {
            setState(() {
              _progress = progress;
            });
          },
        );

        setState(() {
          _isConverting = false;
          _status = 'Conversion completed';
          _convertedFiles.add(outputFile);
        });
      } else {
        // 批量转换
        final outputFiles = await _conversionService.batchConvertFiles(
          _selectedFiles,
          _outputFormat,
          onProgress: (index, progress) {
            setState(() {
              _progress = (index + progress) / _selectedFiles.length;
              _status = 'Converting ${index + 1}/${_selectedFiles.length}...';
            });
          },
        );

        setState(() {
          _isConverting = false;
          _status = 'Batch conversion completed: ${outputFiles.length}/${_selectedFiles.length} files';
          _convertedFiles.addAll(outputFiles);
        });
      }
    } catch (e) {
      setState(() {
        _isConverting = false;
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FFmpeg Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // 显示转换历史
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Converted Files'),
                  content: _convertedFiles.isEmpty
                      ? const Text('No files converted yet')
                      : ListView.builder(
                          itemCount: _convertedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _convertedFiles[index];
                            return ListTile(
                              title: Text(_fileService.getFileName(file.path)),
                              subtitle: Text(file.path),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new),
                                onPressed: () {
                                  // 打开文件
                                },
                              ),
                            );
                          },
                        ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 状态信息
            Text(
              _status,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 文件选择
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConverting ? null : _selectFile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _selectedFile != null
                          ? 'Selected: ${_fileService.getFileName(_selectedFile!.path)}'
                          : 'Select File',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isConverting ? null : _selectMultipleFiles,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Batch Select'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 格式选择
            if (_selectedFile != null) ...[
              Row(
                children: [
                  const Text('Output Format: '),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _outputFormat,
                      onChanged: _isConverting
                          ? null
                          : (value) {
                              setState(() {
                                _outputFormat = value!;
                              });
                            },
                      items: (
                        ConverterUtils.isVideoFile(_selectedFile!.path)
                            ? ConverterUtils.getVideoFormats()
                            : ConverterUtils.getAudioFormats()
                      ).entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 转换按钮
              ElevatedButton(
                onPressed: _isConverting ? null : _convertFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Convert'),
              ),
              const SizedBox(height: 20),

              // 进度条
              if (_isConverting) ...[
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                ),
                const SizedBox(height: 10),
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
