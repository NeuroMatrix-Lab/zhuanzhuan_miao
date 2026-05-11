import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
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
  
  bool _isDragging = false;
  File? _selectedFile;
  String _outputFormat = 'mp4';
  double _progress = 0.0;
  bool _isConverting = false;
  String _status = 'Ready';
  String? _outputPath;

  @override
  void initState() {
    super.initState();
    _conversionService = ConversionService(_ffmpegService, _fileService);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _status = 'Selected: ${_fileService.getFileName(_selectedFile!.path)}';
        _outputPath = null;
      });
    }
  }

  void _onDropFiles(List<File> files) {
    if (files.isNotEmpty) {
      setState(() {
        _selectedFile = files.first;
        _status = 'Selected: ${_fileService.getFileName(_selectedFile!.path)}';
        _outputPath = null;
      });
    }
  }

  Future<void> _selectOutputLocation() async {
    if (_selectedFile == null) return;

    final fileName = _fileService.getFileName(_selectedFile!.path);
    final nameWithoutExtension = fileName.split('.').first;
    final defaultFileName = '$nameWithoutExtension.$_outputFormat';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Choose save location',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: [_outputFormat],
    );

    if (result != null) {
      setState(() {
        _outputPath = result;
        _status = 'Save to: $result';
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

    if (_outputPath == null) {
      setState(() {
        _status = 'Please select output location first';
      });
      return;
    }

    setState(() {
      _isConverting = true;
      _progress = 0.0;
      _status = 'Converting...';
    });

    try {
      final outputDir = await _fileService.getOutputDirectory();
      final outputFileName = _fileService.getOutputPath(_outputPath!, _outputFormat);
      final fullOutputPath = '${outputDir.path}${Platform.pathSeparator}$outputFileName';

      await _conversionService.convertFile(
        _selectedFile!,
        _outputFormat,
        customOutputPath: fullOutputPath,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      setState(() {
        _isConverting = false;
        _status = 'Conversion completed!';
      });
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
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _outputPath = null;
                  _status = 'Ready';
                });
              },
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: Column(
        children: [
          // 顶部拖拽区域
          if (_selectedFile == null) _buildDropZone(),
          
          // 主要内容区域 - 左右分栏
          if (_selectedFile != null)
            Expanded(
              child: Row(
                children: [
                  // 左侧 - 文件信息
                  Expanded(
                    child: _buildFileListPanel(),
                  ),
                  
                  // 分隔线
                  Container(
                    width: 1,
                    color: Colors.grey[300],
                  ),
                  
                  // 右侧 - 格式选择
                  Expanded(
                    child: _buildFormatPanel(),
                  ),
                ],
              ),
            ),
          
          // 底部状态栏
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildDropZone() {
    return Expanded(
      child: DropTarget(
        onDragDone: (details) {
          final files = details.files.map((f) => File(f.path)).toList();
          _onDropFiles(files);
        },
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        child: GestureDetector(
          onTap: _pickFile,
          child: Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isDragging ? Colors.blue : Colors.grey,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
              color: _isDragging 
                  ? Colors.blue.withAlpha(25) 
                  : Colors.grey.withAlpha(13),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDragging ? Icons.file_download : Icons.upload_file,
                    size: 64,
                    color: _isDragging ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isDragging 
                        ? 'Release to select file' 
                        : 'Drag and drop a file here',
                    style: TextStyle(
                      fontSize: 18,
                      color: _isDragging ? Colors.blue : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'or click to select',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileListPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected File',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          // 文件信息卡片
          Card(
            child: ListTile(
              leading: Icon(
                ConverterUtils.isVideoFile(_selectedFile!.path)
                    ? Icons.video_file
                    : Icons.audio_file,
                size: 40,
              ),
              title: Text(
                _fileService.getFileName(_selectedFile!.path),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Extension: .${_fileService.getFileExtension(_selectedFile!.path)}',
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 输出路径
          if (_outputPath != null) ...[
            Text(
              'Output Location',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.save_alt),
                title: Text(
                  _outputPath!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          
          const Spacer(),
          
          // 进度条
          if (_isConverting) ...[
            LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          
          // 转换按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_isConverting || _outputPath == null) 
                  ? null 
                  : _convertFile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              icon: const Icon(Icons.play_arrow),
              label: Text(_isConverting ? 'Converting...' : 'Convert'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatPanel() {
    final isVideo = ConverterUtils.isVideoFile(_selectedFile!.path);
    final formats = isVideo 
        ? ConverterUtils.getVideoFormats() 
        : ConverterUtils.getAudioFormats();

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Output Format',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            isVideo ? 'Video formats' : 'Audio formats',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          
          // 格式网格
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: formats.length,
              itemBuilder: (context, index) {
                final entry = formats.entries.elementAt(index);
                final isSelected = entry.key == _outputFormat;
                
                return InkWell(
                  onTap: () {
                    setState(() {
                      _outputFormat = entry.key;
                      _outputPath = null; // 清空输出路径，因为文件名可能需要改变
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected 
                          ? Colors.blue.withAlpha(25) 
                          : Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVideo ? Icons.video_file : Icons.audio_file,
                          size: 32,
                          color: isSelected ? Colors.blue : Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontWeight: isSelected 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: isSelected ? Colors.blue : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 选择保存位置按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _selectOutputLocation,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.folder_open),
              label: Text(_outputPath == null 
                  ? 'Select Save Location' 
                  : 'Change Save Location'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConverting ? Icons.sync : Icons.info_outline,
            size: 20,
            color: _isConverting ? Colors.blue : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _status,
              style: TextStyle(
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
