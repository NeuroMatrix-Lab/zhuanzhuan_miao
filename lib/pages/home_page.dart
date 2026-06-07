import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDragging = false;
  List<File> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D3F),
        title: const Text(
          'FFmpeg Converter',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: _selectedFiles.isEmpty
            ? _buildDropZone()
            : _buildFileList(),
      ),
    );
  }

  Widget _buildDropZone() {
    return DropTarget(
      onDragDone: (details) {
        setState(() {
          _selectedFiles = details.files
              .map((xFile) => File(xFile.path))
              .where((file) => _isMediaFile(file.path))
              .toList();
        });
        if (_selectedFiles.isNotEmpty) {
          _navigateToConverter();
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _pickFiles,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 500,
            height: 350,
            decoration: BoxDecoration(
              color: _isDragging
                  ? const Color(0xFF3D3D5C)
                  : const Color(0xFF2D2D3F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDragging
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF4A4A6A),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isDragging ? Icons.file_download : Icons.video_file_outlined,
                  size: 80,
                  color: _isDragging
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(height: 24),
                Text(
                  _isDragging
                      ? '松开以选择文件'
                      : '点击选择或拖放媒体文件',
                  style: TextStyle(
                    fontSize: 18,
                    color: _isDragging
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '支持视频: MP4, AVI, MKV, MOV, WebM\n支持音频: MP3, WAV, AAC, FLAC, OGG',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('添加更多文件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedFiles.clear());
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('清空'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                  side: const BorderSide(color: Color(0xFF4A4A6A)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              return _buildFileCard(file);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedFiles.isNotEmpty ? _navigateToConverter : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: const Color(0xFF3D3D5C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '开始转换',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(File file) {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D3F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4A6A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                extension,
                style: const TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getFileSize(file),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
            onPressed: () {
              setState(() {
                _selectedFiles.remove(file);
              });
            },
          ),
        ],
      ),
    );
  }

  String _getFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  bool _isMediaFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    const mediaExtensions = [
      'mp4', 'avi', 'mkv', 'mov', 'webm', 'wmv', 'flv',
      'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma',
      'gif', 'jpg', 'jpeg', 'png', 'bmp', 'webp',
    ];
    return mediaExtensions.contains(ext);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp4', 'avi', 'mkv', 'mov', 'webm', 'wmv', 'flv',
        'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma',
        'gif', 'jpg', 'jpeg', 'png', 'bmp', 'webp',
      ],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
      });
      if (_selectedFiles.isNotEmpty) {
        _navigateToConverter();
      }
    }
  }

  void _navigateToConverter() {
    Navigator.pushNamed(
      context,
      '/converter',
      arguments: _selectedFiles,
    ).then((_) {
      // 当从转换页面返回时刷新列表
      setState(() {});
    });
  }
}
