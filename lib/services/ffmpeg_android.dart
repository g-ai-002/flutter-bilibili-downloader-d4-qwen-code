/// Android 平台 ffmpeg 合并实现，使用 ffmpeg_kit_extended_flutter。
/// 仅在 pubspec 包含 ffmpeg_kit_extended_flutter 时编译。
library ffmpeg_android;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import '../models/video_metadata.dart';
import 'log_service.dart';

Future<void> initializeFfmpeg() async {
  await FFmpegKitExtended.initialize();
  LogService.info('ffmpeg_kit_extended_flutter 初始化完成');
}

/// 解析视频文件的媒体信息（使用 FFprobeKit）
Future<VideoMetadata?> probeMediaPlatform(String filePath) async {
  try {
    final command =
        '-v quiet -print_format json -show_format -show_streams "$filePath"';
    final session = await FFprobeKit.execute(command);
    final output = session.getOutput();
    if (output == null || output.isEmpty) return null;
    return _parseFfprobeJson(output, filePath);
  } catch (e) {
    LogService.warning('Android 平台解析媒体信息失败: $filePath | $e');
    return null;
  }
}

/// 从 ffprobe JSON 输出解析元数据
VideoMetadata? _parseFfprobeJson(String jsonStr, String filePath) {
  try {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final streams = data['streams'] as List<dynamic>? ?? [];
    final format = data['format'] as Map<String, dynamic>?;

    int? width;
    int? height;
    double? fps;
    String? videoCodec;
    String? audioCodec;
    int? fileSize;

    if (format != null) {
      final sizeStr = format['size'] as String?;
      if (sizeStr != null) {
        fileSize = int.tryParse(sizeStr);
      }
    }
    if (fileSize == null) {
      final file = File(filePath);
      fileSize = file.existsSync() ? file.lengthSync() : null;
    }

    for (final stream in streams) {
      final codecType = stream['codec_type'] as String?;
      if (codecType == 'video') {
        width = stream['width'] as int?;
        height = stream['height'] as int?;
        videoCodec = (stream['codec_name'] as String?)?.toUpperCase();

        final fpsStr = stream['r_frame_rate'] as String?;
        if (fpsStr != null && fpsStr.contains('/')) {
          final parts = fpsStr.split('/');
          final num = double.tryParse(parts[0]);
          final den = double.tryParse(parts[1]);
          if (num != null && den != null && den > 0) {
            fps = num / den;
          }
        }
      } else if (codecType == 'audio') {
        audioCodec = (stream['codec_name'] as String?)?.toUpperCase();
      }
    }

    if (width == null && videoCodec == null && audioCodec == null) return null;

    return VideoMetadata(
      width: width,
      height: height,
      fps: fps,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      fileSize: fileSize,
    );
  } catch (e) {
    LogService.error('解析 ffprobe JSON 失败', e);
    return null;
  }
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
