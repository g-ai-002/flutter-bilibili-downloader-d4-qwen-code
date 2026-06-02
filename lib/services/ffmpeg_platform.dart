/// FFmpeg 平台实现入口。
/// 此文件在 CI 构建时根据目标平台自动互换：
///   - Windows 构建: 内容 = ffmpeg_windows.dart（使用原生 ffmpeg Process.start）
///   - Android 构建: 内容 = ffmpeg_android.dart（使用 ffmpeg_kit_extended_flutter）
///
/// 本地开发默认使用 Windows 版本（与默认 pubspec.yaml 匹配）。
library ffmpeg_platform;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/video_metadata.dart';
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
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['ffmpeg'],
      ).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        final out = (result.stdout?.toString() ?? '').trim();
        if (out.isNotEmpty) {
          _ffmpegPath = out.split(RegExp(r'[\r\n]+')).first.trim();
          return _ffmpegPath;
        }
      }
    } on TimeoutException {
      LogService.warning('where/which ffmpeg 超时');
    }
  } catch (_) {}
  _ffmpegPath = null;
  return null;
}

Future<void> initializeFfmpeg() async {
  // Windows 平台不需要额外初始化，ffmpeg 在合并时按需查找
}

/// 解析视频文件的媒体信息（使用 ffprobe）
/// 返回 null 表示 ffprobe 不可用或解析失败
Future<VideoMetadata?> probeMediaPlatform(String filePath) async {
  try {
    final ff = await _resolveFfmpeg();
    if (ff == null) {
      LogService.warning('未检测到 ffmpeg，无法解析媒体信息');
      return null;
    }
    // ffprobe 通常与 ffmpeg 在同一目录
    final exeDir = File(ff).parent.path;
    final ffprobeExe = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
    final ffprobePath = '$exeDir${Platform.pathSeparator}$ffprobeExe';
    final ffprobe = await File(ffprobePath).exists()
        ? ffprobePath
        : null;

    // 回退到直接用 ffmpeg 获取信息（ffmpeg -i 也会输出流信息到 stderr）
    final useFfmpeg = ffprobe == null;
    final execPath = ffprobe ?? ff;
    final args = useFfmpeg
        ? ['-i', filePath]
        : ['-v', 'quiet', '-print_format', 'json', '-show_format', '-show_streams', filePath];

    try {
      final result = await Process.run(
        execPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 10));

      if (useFfmpeg) {
      // ffmpeg -i 输出到 stderr，手动解析
      return _parseFfmpegInfo(result.stderr as String?, filePath);
    }

    if (result.exitCode != 0) {
      LogService.warning('ffprobe 执行失败: ${result.stderr}');
      return null;
    }

    final stdout = result.stdout as String?;
    if (stdout == null || stdout.isEmpty) return null;

    return _parseFfprobeJson(stdout, filePath);
  } catch (e) {
    LogService.error('解析媒体信息失败: $filePath', e);
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

    // 文件大小
    if (format != null) {
      final sizeStr = format['size'] as String?;
      if (sizeStr != null) {
        fileSize = int.tryParse(sizeStr);
      }
    }
    if (fileSize == null) {
      // 回退：直接获取文件大小
      final file = File(filePath);
      fileSize = file.existsSync() ? file.lengthSync() : null;
    }

    for (final stream in streams) {
      final codecType = stream['codec_type'] as String?;
      if (codecType == 'video') {
        width = stream['width'] as int?;
        height = stream['height'] as int?;
        videoCodec = (stream['codec_name'] as String?)?.toUpperCase();

        // 帧率：r_frame_rate 格式为 "30000/1001"
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

/// 从 ffmpeg -i 的 stderr 输出手动解析（ffprobe 不可用时的回退方案）
VideoMetadata? _parseFfmpegInfo(String? stderr, String filePath) {
  if (stderr == null || stderr.isEmpty) return null;
  try {
    int? width;
    int? height;
    double? fps;
    String? videoCodec;
    String? audioCodec;
    int? fileSize;

    final lines = stderr.split(RegExp(r'[\r\n]+'));
    for (final line in lines) {
      if (line.contains('Stream #') && line.contains('Video:')) {
        // 例: Stream #0:0: Video: h264 (avc1 / 0x31637661), yuv420p, 1920x1080, 30 fps
        videoCodec = _extractCodec(line, 'Video:');
        width = _extractResolution(line, 0);
        height = _extractResolution(line, 1);
        fps = _extractFps(line);
      } else if (line.contains('Stream #') && line.contains('Audio:')) {
        // 例: Stream #0:1: Audio: aac (mp4a / 0x6134706D), 44100 Hz, stereo
        audioCodec = _extractCodec(line, 'Audio:');
      }
    }

    if (filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        fileSize = file.lengthSync();
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
    LogService.error('解析 ffmpeg -i 输出失败', e);
    return null;
  }
}

String? _extractCodec(String line, String keyword) {
  final idx = line.indexOf(keyword);
  if (idx < 0) return null;
  final after = line.substring(idx + keyword.length).trim();
  // 取第一个空格或逗号前的词作为编码器名
  final codec = after.split(RegExp(r'[ ,(]')).first.trim();
  return codec.isNotEmpty ? codec.toUpperCase() : null;
}

int? _extractResolution(String line, int idx) {
  // 匹配 1920x1080 模式
  final match = RegExp(r'(\d{2,5})x(\d{2,5})').firstMatch(line);
  if (match == null) return null;
  if (idx == 0) return int.tryParse(match.group(1)!);
  return int.tryParse(match.group(2)!);
}

double? _extractFps(String line) {
  // 匹配 "30 fps" 或 "29.97 fps"
  final match = RegExp(r'(\d+\.?\d*)\s*fps').firstMatch(line);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
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
