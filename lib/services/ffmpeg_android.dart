/// Android 平台 ffmpeg 合并实现，使用 ffmpeg_kit_extended_flutter。
/// 仅在 pubspec 包含 ffmpeg_kit_extended_flutter 时编译。
library ffmpeg_android;

import 'dart:async';
import 'dart:io';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'log_service.dart';

Future<void> initializeFfmpeg() async {
  await FFmpegKitExtended.initialize();
  LogService.info('ffmpeg_kit_extended_flutter 初始化完成');
}

Future<String?> mergeAvPlatform({
  required String videoPath,
  required String audioPath,
  required String outputPath,
}) async {
  try {
    final command =
        '-y -i "$videoPath" -i "$audioPath" -c:v copy -c:a copy -map 0:v:0 -map 1:a:0 "$outputPath"';
    LogService.info('ffmpeg 无损合并开始 (ffmpeg_kit): $command');
    final completer = Completer<Session>();
    FFmpegKit.executeAsync(
      command,
      onComplete: (session) => completer.complete(session),
    );
    final session = await completer.future;
    final returnCode = session.getReturnCode();
    if (returnCode != null && ReturnCode.isSuccess(returnCode)) {
      if (await File(outputPath).exists()) {
        try {
          await File(videoPath).delete();
          await File(audioPath).delete();
        } catch (_) {}
        LogService.info('ffmpeg 无损合并成功: $outputPath');
        return outputPath;
      }
    }
    final failStack = session.getFailStackTrace();
    LogService.error(
      'ffmpeg 无损合并失败',
      'stderr: ${failStack ?? "无"}',
    );
  } catch (e) {
    LogService.error('ffmpeg 无损合并异常', e);
  }
  return null;
}
