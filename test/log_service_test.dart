import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bilibili_downloader_d4_qwen_code/services/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    LogService.reset();
    tempDir = await Directory.systemTemp.createTemp('log_service_test');
  });

  tearDown(() async {
    LogService.reset();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('日志目录不可用时降级为仅内存模式且不抛', () async {
    await LogService.init(
      logRoot: () => throw StateError('目录不可用'),
    );
    LogService.info('测试日志条目');
    LogService.warning('测试告警条目');
    LogService.error('测试错误条目', StateError('boom'));

    final logs = LogService.getRecentLogs();
    expect(logs.length, 4);
    expect(logs.any((l) => l.contains('测试日志条目')), isTrue);
    expect(logs.any((l) => l.contains('测试告警条目')), isTrue);
    expect(logs.any((l) => l.contains('boom')), isTrue);
    expect(LogService.logFilePath, '');
  });

  test('日志行带级别与时间戳格式', () async {
    await LogService.init(logRoot: () async => tempDir);
    LogService.info('格式检查');
    final line = LogService.getRecentLogs().last;
    expect(
      RegExp(r'^\[\d{2}:\d{2}:\d{2}\.\d{3}\]\[INFO\] 格式检查$').hasMatch(line),
      isTrue,
    );
  });

  test('日志写入当日文件', () async {
    await LogService.init(logRoot: () async => tempDir);
    LogService.info('落盘条目');
    final path = LogService.logFilePath;
    expect(path, isNotEmpty);
    expect(await File(path).readAsString(), contains('落盘条目'));
  });

  test('初始化前的日志进入早期缓冲并在初始化后补写', () async {
    LogService.info('早期日志');
    await LogService.init(logRoot: () async => tempDir);
    final path = LogService.logFilePath;
    expect(path, isNotEmpty);
    expect(await File(path).readAsString(), contains('早期日志'));
    expect(
      LogService.getRecentLogs().any((l) => l.contains('早期日志')),
      isTrue,
    );
  });

  test('跨天自动切换日志文件', () async {
    var fakeNow = DateTime(2026, 10, 22, 23, 59, 58);
    await LogService.init(
      logRoot: () async => tempDir,
      clock: () => fakeNow,
    );
    LogService.info('第一天日志');
    fakeNow = DateTime(2026, 10, 23, 0, 0, 1);
    LogService.info('第二天日志');

    final day1 =
        File('${tempDir.path}${Platform.pathSeparator}app_20261022.log');
    final day2 =
        File('${tempDir.path}${Platform.pathSeparator}app_20261023.log');
    expect(await day1.exists(), isTrue);
    expect(await day2.exists(), isTrue);
    expect(await day1.readAsString(), contains('第一天日志'));
    expect(await day2.readAsString(), contains('第二天日志'));
  });

  test('单文件超过大小上限自动轮转', () async {
    await LogService.init(logRoot: () async => tempDir);
    final path = LogService.logFilePath;
    expect(path, isNotEmpty);
    await File(path).writeAsString('x' * (5 * 1024 * 1024 + 1024));
    LogService.info('触发轮转');

    final names =
        await tempDir.list().map((e) => e.uri.pathSegments.last).toList();
    expect(names.where((n) => n.endsWith('_1.log')), hasLength(1));
    expect(await File(path).readAsString(), contains('触发轮转'));
  });
}
