import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// 日志服务
class LogService {
  static LogService? _instance;
  late final File _logFile;
  final List<String> _buffer = [];
  static const int _maxBufferLines = 1000;

  LogService._();

  static Future<LogService> get instance async {
    _instance ??= LogService._();
    await _instance!._init();
    return _instance!;
  }

  static Future<void> init() async {
    _instance ??= LogService._();
    await _instance!._init();
  }

  Future<void> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    _logFile = File('${logDir.path}/app_$dateStr.log');
    if (!await _logFile.exists()) {
      await _logFile.create();
    }
  }

  static void info(String message) {
    _instance?._log('INFO', message);
  }

  static void warning(String message) {
    _instance?._log('WARN', message);
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    _instance?._log('ERROR', msg);
    if (stack != null) {
      _instance?._log('ERROR', stack.toString());
    }
  }

  void _log(String level, String message) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
    final line = '[$timeStr][$level] $message';
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }
    // 异步写入文件
    _logFile.writeAsStringSync('$line\n', mode: FileMode.append);
  }

  static Future<String> getLogContent() async {
    if (_instance == null) return '';
    return _instance!._logFile.readAsString();
  }

  static List<String> getRecentLogs([int lines = 100]) {
    if (_instance == null) return [];
    final buffer = _instance!._buffer;
    if (buffer.length <= lines) return List.from(buffer);
    return buffer.sublist(buffer.length - lines);
  }

  static Future<String> getLogFilePath() async {
    if (_instance == null) return '';
    return _instance!._logFile.path;
  }
}
