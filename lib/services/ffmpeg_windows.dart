/// Windows 平台 ffmpeg 合并实现，使用原生 ffmpeg（Process.start）。
/// 不依赖 ffmpeg_kit_extended_flutter，确保 Windows 构建无需该包。
library ffmpeg_windows;

import 'dart:convert';
import 'dart:io';
import 'log_service.dart';

String? _ffmpegPath;
bool _ffmpegResolved = false;

/// 检测 ffmpeg 可执行文件路径
/// 优先顺序：
///   1. 应用同目录下的 ffmpeg.exe（CI 已打包）
///   2. 系统 PATH
/// 找不到返回 null
Future<String?> _resolveFfmpeg() async {
  if (_ffmpegResolved) return _ffmpegPath;
  _ffmpegResolved = true;
  try {
    final exe = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    // 1) 应用同目录
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = File('$exeDir${Platform.pathSeparator}$exe');
    if (await bundled.exists()) {
      _ffmpegPath = bundled.path;
      return _ffmpegPath;
    }
    // 2) PATH
    final result = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      ['ffmpeg'],
    );
    if (result.exitCode == 0) {
      final out = (result.stdout?.toString() ?? '').trim();
      if (out.isNotEmpty) {
        _ffmpegPath = out.split(RegExp(r'[\r\n]+')).first.trim();
        return _ffmpegPath;
      }
    }
  } catch (_) {}
  _ffmpegPath = null;
  return null;
}

Future<void> initializeFfmpeg() async {
  // Windows 平台不需要额外初始化，ffmpeg 在合并时按需查找
}

Future<String?> mergeAvPlatform({
  required String videoPath,
  required String audioPath,
  required String outputPath,
}) async {
  try {
    final ff = await _resolveFfmpeg();
    if (ff == null) {
      LogService.warning('未检测到 ffmpeg，跳过合并');
      return null;
    }
    final args = [
      '-y',
      '-i', videoPath,
      '-i', audioPath,
      '-c:v', 'copy',
      '-c:a', 'copy',
      '-map', '0:v:0',
      '-map', '1:a:0',
      outputPath,
    ];
    LogService.info('ffmpeg 无损合并开始 (原生): $ff ${args.join(" ")}');
    final process = await Process.start(ff, args);
    // 同时 drain stdout/stderr 避免管道缓冲区满阻塞进程
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    await stdoutFuture; // 确保 stdout drain 完成
    final stderrStr = await stderrFuture;
    if (exitCode == 0 && await File(outputPath).exists()) {
      try {
        await File(videoPath).delete();
        await File(audioPath).delete();
      } catch (_) {}
      LogService.info('ffmpeg 无损合并成功: $outputPath');
      return outputPath;
    }
    LogService.error(
      'ffmpeg 合并失败 (exitCode=$exitCode)',
      stderrStr,
    );
  } catch (e) {
    LogService.error('ffmpeg 调用异常', e);
  }
  return null;
}
