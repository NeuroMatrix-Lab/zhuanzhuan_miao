import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._private();
  late File _logFile;

  factory LogService() {
    return _instance;
  }

  LogService._private();

  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logFile = File('${logDir.path}/converter_${DateTime.now().toIso8601String().split('T')[0]}.log');
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    if (!_logFile.existsSync()) {
      await init();
    }
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] $message\n';
    await _logFile.writeAsString(logEntry, mode: FileMode.append);
  }

  Future<void> info(String message) async {
    await log(message, level: 'INFO');
  }

  Future<void> error(String message, [Object? error]) async {
    final errorMessage = error != null ? '$message: $error' : message;
    await log(errorMessage, level: 'ERROR');
  }

  Future<void> debug(String message) async {
    await log(message, level: 'DEBUG');
  }

  Future<String> getLogContent() async {
    if (!_logFile.existsSync()) {
      return 'No logs available';
    }
    return await _logFile.readAsString();
  }

  Future<void> clearLogs() async {
    if (_logFile.existsSync()) {
      await _logFile.delete();
    }
  }
}
