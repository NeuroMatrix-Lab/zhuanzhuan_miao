import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  Future<File?> pickFile({List<String>? allowedExtensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );

    if (result != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  Future<List<File>> pickMultipleFiles({List<String>? allowedExtensions}) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );

    if (result != null) {
      return result.files.map((file) => File(file.path!)).toList();
    }
    return [];
  }

  Future<Directory> getOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${directory.path}/converted');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    return outputDir;
  }

  String getOutputPath(String inputPath, String extension) {
    final fileName = inputPath.split(Platform.pathSeparator).last;
    final nameWithoutExtension = fileName.split('.').first;
    return '$nameWithoutExtension.$extension';
  }

  String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  String getFileName(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}
