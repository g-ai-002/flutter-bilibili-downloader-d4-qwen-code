import 'dart:io';
import 'ffmpeg_platform.dart';
import '../models/video_metadata.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'log_service.dart';

/// 文件系统相关辅助服务：
/// - 下载根目录解析（Windows/Android 差异化）
/// - 日志目录解析
/// - 打开文件管理器并定位到目标文件
/// - DASH 视频/音频合并（委托给 ffmpeg_platform.dart）
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

    Directory baseDir;
    if (Platform.isAndroid) {
      final extDir = await getExternalStorageDirectory();
      baseDir = extDir ?? await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final logDir = Directory('${baseDir.path}/logs');
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

  /// 使用系统默认播放器打开视频文件
  Future<bool> openWithSystemPlayer(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
        return true;
      } else if (Platform.isAndroid) {
        return _openOnAndroid(filePath);
      } else {
        final file = File(filePath);
        final exists = await file.exists();
        LogService.info('尝试播放文件: $filePath, 存在: $exists, 大小: ${exists ? await file.length() : 0}');
        final uri = Uri.file(filePath);
        final canLaunch = await canLaunchUrl(uri);
        LogService.info('canLaunchUrl($uri): $canLaunch');
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          LogService.warning('无法打开播放器: canLaunchUrl 返回 false, path=$filePath');
        }
      }
    } catch (e, stack) {
      LogService.error('打开播放器失败: $filePath', e, stack);
    }
    return false;
  }

  /// Android: 通过 FileProvider 将 file:// 转为 content:// URI 再调用系统播放器。
  /// Android 7.0+ 禁止向其他应用暴露 file:// URI（FileUriExposedException），
  /// 必须使用 content:// URI + FileProvider 授权。
  Future<bool> _openOnAndroid(String filePath) async {
    final file = File(filePath);
    final exists = await file.exists();
    LogService.info('尝试播放文件: $filePath, 存在: $exists, 大小: ${exists ? await file.length() : 0}');

    if (!exists) {
      LogService.warning('文件不存在，无法播放: $filePath');
      return false;
    }

    // 获取外部存储根目录，与 FileProvider 的 external-files-path 对应
    final extDir = await getExternalStorageDirectory();
    if (extDir == null) {
      LogService.warning('无法获取外部存储目录，无法构造 content URI');
      return false;
    }

    // file_paths.xml 中映射了 Movies/ 目录，这里计算相对路径
    final basePath = '${extDir.path}/Movies/';
    if (!filePath.startsWith(basePath)) {
      LogService.warning('文件不在外部存储 Movies 目录下，无法通过 FileProvider 访问: $filePath');
      return false;
    }

    final relativePath = filePath.substring(basePath.length);
    // 编码路径中的中文、空格等特殊字符，确保 content URI 合法
    final encodedSegments = relativePath
        .split('/')
        .map((s) => Uri.encodeComponent(s))
        .join('/');
    // 与 AndroidManifest.xml 中 FileProvider 的 authorities 保持一致
    final contentUri = Uri.parse(
      'content://com.bilibili.downloader.fileprovider/movies/$encodedSegments',
    );

    LogService.info('Android content URI: $contentUri');
    final canLaunch = await canLaunchUrl(contentUri);
    LogService.info('canLaunchUrl($contentUri): $canLaunch');
    if (canLaunch) {
      await launchUrl(contentUri, mode: LaunchMode.externalApplication);
      return true;
    } else {
      LogService.warning('无法打开播放器: canLaunchUrl 返回 false, contentUri=$contentUri');
      return false;
    }
  }

  /// 合并视频轨与音频轨（无损流复制）
  /// 委托给平台特定实现（ffmpeg_platform.dart）。
  /// 成功返回输出路径，失败返回 null
  Future<String?> mergeAv({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    return mergeAvPlatform(
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: outputPath,
    );
  }

  /// 解析视频文件的媒体信息（分辨率、帧率、编码等）
  /// 委托给平台特定实现（ffmpeg_platform.dart）。
  /// 返回 null 表示解析不可用
  Future<VideoMetadata?> probeMedia(String filePath) async {
    return probeMediaPlatform(filePath);
  }
}
