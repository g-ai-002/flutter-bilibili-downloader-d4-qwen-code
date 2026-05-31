import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'log_service.dart';

/// 文件系统相关辅助服务：
/// - 下载根目录解析（Windows/Android 差异化）
/// - 日志目录解析
/// - 打开文件管理器并定位到目标文件
/// - DASH 视频/音频合并（依赖系统 ffmpeg）
class FileSystemService {
  static FileSystemService? _instance;
  static FileSystemService get instance => _instance ??= FileSystemService._();
  FileSystemService._();

  Directory? _downloadRoot;
  Directory? _logRoot;

  /// 获取下载根目录
  /// - Android: /storage/emulated/0/Android/data/<pkg>/files/Movies/Bilibili
  ///   使用应用专属外部存储（minSdk 34 无需任何权限），可通过系统文件管理器访问
  /// - Windows / 其他: <用户文档>/BilibiliDownloader
  Future<Directory> getDownloadRoot() async {
    if (_downloadRoot != null) return _downloadRoot!;

    Directory root;
    if (Platform.isAndroid) {
      // 外部应用专属存储 -> /storage/emulated/0/Android/data/<pkg>/files
      final extDir = await getExternalStorageDirectory();
      final base = extDir ?? await getApplicationDocumentsDirectory();
      root = Directory('${base.path}/Movies/Bilibili');
    } else if (Platform.isWindows) {
      // Windows: 用户视频目录的子目录优先；回退到 Documents
      final videos = await _resolveWindowsVideosDir();
      if (videos != null) {
        root = Directory('${videos.path}\\BilibiliDownloader');
      } else {
        final docs = await getApplicationDocumentsDirectory();
        root = Directory('${docs.path}\\BilibiliDownloader');
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      root = Directory('${docs.path}/BilibiliDownloader');
    }

    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _downloadRoot = root;
    return root;
  }

  Future<Directory?> _resolveWindowsVideosDir() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile == null || userProfile.isEmpty) return null;
      final videos = Directory('$userProfile\\Videos');
      if (await videos.exists()) return videos;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取日志根目录（仅文件父目录，路径展示用）
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _logRoot = logDir;
    return logDir;
  }

  /// 打开文件所在目录（桌面端原生支持，Android 端无系统级"显示在文件管理器"，
  /// 调用方应在 Android 端展示路径供复制）
  Future<bool> revealInFileManager(String path) async {
    try {
      if (Platform.isWindows) {
        final file = File(path);
        final exists = await file.exists();
        if (exists) {
          await Process.run('explorer.exe', ['/select,', path]);
        } else {
          // 文件不存在则尝试打开父目录
          final parent = File(path).parent.path;
          await Process.run('explorer.exe', [parent]);
        }
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
        return true;
      } else if (Platform.isLinux) {
        final parent = File(path).parent.path;
        await Process.run('xdg-open', [parent]);
        return true;
      }
    } catch (e) {
      LogService.error('打开文件管理器失败: $path', e);
    }
    return false;
  }

  /// 打开目录
  Future<bool> openDirectory(String dirPath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [dirPath]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [dirPath]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dirPath]);
        return true;
      }
    } catch (e) {
      LogService.error('打开目录失败: $dirPath', e);
    }
    return false;
  }

  /// 检测 ffmpeg 可执行文件路径
  /// 优先顺序：
  ///   1. 应用同目录下的 ffmpeg.exe / ffmpeg（CI 已打包）
  ///   2. 系统 PATH
  /// 找不到返回 null
  String? _ffmpegPath;
  bool _ffmpegResolved = false;
  Future<String?> resolveFfmpeg() async {
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

  /// 检测系统 ffmpeg 是否可用
  Future<bool> hasFFmpeg() async => (await resolveFfmpeg()) != null;

  /// 合并视频轨与音频轨（依赖系统/打包 ffmpeg）
  /// 成功返回输出路径，失败返回 null
  Future<String?> mergeAv({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    try {
      final ff = await resolveFfmpeg();
      if (ff == null) {
        LogService.warning('未检测到 ffmpeg，跳过合并');
        return null;
      }
      final args = [
        '-y',
        '-i', videoPath,
        '-i', audioPath,
        '-c', 'copy',
        outputPath,
      ];
      final result = await Process.run(ff, args);
      if (result.exitCode == 0 && await File(outputPath).exists()) {
        // 合并成功，删除中间文件
        try {
          await File(videoPath).delete();
          await File(audioPath).delete();
        } catch (_) {}
        return outputPath;
      }
      LogService.error(
        'ffmpeg 合并失败 (exitCode=${result.exitCode})',
        result.stderr?.toString() ?? '',
      );
    } catch (e) {
      LogService.error('ffmpeg 调用异常', e);
    }
    return null;
  }
}
