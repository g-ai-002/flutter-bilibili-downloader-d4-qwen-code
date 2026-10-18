// 临时验证用测试：在 Windows 上以「进程内 FFI」方式跑 ffmpeg-kit 的无损合并。
// 只由 .gitea/workflows/verify-windows-ffmpegkit.yml 复制进 test/ 后执行，
// 正常的 flutter test（Linux 任务）不会运行它；验证结束可连同工作流一起删除。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

/// 与 lib/services/ffmpeg_platform.dart 相同的调用方式（executeAsync + Completer）
Future<Session> _run(String command) {
  final completer = Completer<Session>();
  FFmpegKit.executeAsync(
    command,
    onComplete: (session) => completer.complete(session),
  );
  return completer.future.timeout(const Duration(minutes: 3));
}

Future<Session> _probe(String filePath) {
  return FFprobeKit.execute(
    '-v quiet -print_format json -show_format -show_streams "$filePath"',
  );
}

bool _ok(Session session) {
  final returnCode = session.getReturnCode();
  return returnCode != null && ReturnCode.isSuccess(returnCode);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sep = Platform.pathSeparator;
  final workDir = Directory('${Directory.systemTemp.path}${sep}ffmpeg_kit_verify');

  setUpAll(() async {
    await FFmpegKitExtended.initialize();
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }
    workDir.createSync(recursive: true);
  });

  test(
    'Windows 上 mp4 复用器可用',
    () async {
      final session = await _run('-hide_banner -muxers');
      final output = session.getOutput() ?? '';
      print('--- -muxers 输出片段 ---\n$output');
      expect(
        output.contains('mp4'),
        isTrue,
        reason: '未在 -muxers 输出中找到 mp4，输出为：\n$output',
      );
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'm4s/m4a 无损合并走生产命令（含中文 emoji 路径）',
    () async {
      final dir = Directory('${workDir.path}${sep}中文 标题 🎬');
      dir.createSync(recursive: true);
      final videoPath = '${dir.path}${sep}ep_video.mp4';
      final audioPath = '${dir.path}${sep}ep_audio.m4a';
      final mergedPath = '${dir.path}${sep}ep.mp4';

      final genVideo = await _run(
        '-hide_banner -f lavfi -i "testsrc=duration=1:size=320x240:rate=10" '
        '-c:v mpeg4 -y "$videoPath"',
      );
      expect(
        _ok(genVideo),
        isTrue,
        reason: '生成测试视频失败：${genVideo.getFailStackTrace()}',
      );

      final genAudio = await _run(
        '-hide_banner -f lavfi -i "sine=duration=1" -c:a aac -y "$audioPath"',
      );
      expect(
        _ok(genAudio),
        isTrue,
        reason: '生成测试音频失败：${genAudio.getFailStackTrace()}',
      );

      // 与线上完全一致的无损合并命令
      final merge = await _run(
        '-y -i "$videoPath" -i "$audioPath" -c:v copy -c:a copy '
        '-map 0:v:0 -map 1:a:0 "$mergedPath"',
      );
      expect(
        _ok(merge),
        isTrue,
        reason: '无损合并失败：${merge.getFailStackTrace()}',
      );
      expect(File(mergedPath).existsSync(), isTrue, reason: '合并产物不存在');

      final probe = await _probe(mergedPath);
      final data = jsonDecode(probe.getOutput() ?? '{}') as Map<String, dynamic>;
      final streams = (data['streams'] as List<dynamic>?) ?? <dynamic>[];
      final types = streams
          .map((s) => (s as Map<String, dynamic>)['codec_type'])
          .toSet();
      print('--- 合并产物流类型：$types ---');
      expect(types.contains('video'), isTrue, reason: '合并产物缺视频轨');
      expect(types.contains('audio'), isTrue, reason: '合并产物缺音频轨');
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
