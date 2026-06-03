/// 应用常量

class AppConstants {
  static const String appName = 'B站视频下载';
  static const String version = '0.4.17';

  // Bilibili API
  static const String bilibiliBaseUrl = 'https://api.bilibili.com';
  static const String bilibiliPassportUrl = 'https://passport.bilibili.com';
  static const String bilibiliWwwUrl = 'https://www.bilibili.com';

  // User-Agent
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  // 下载
  static const int maxConcurrentDownloads = 3;
  static const int maxRetries = 3;
  static const int maxJobs = 50;

  // 画质优先级 (从高到低，文本名)
  static const List<String> qualityPriority = [
    '4K',
    '1080P+',
    '1080P',
    '720P+',
    '720P',
    '480P',
    '360P',
  ];

  /// 画质 quality (qn) 数字 -> 描述名 映射，用于稳定地按整数优先级选择最佳画质
  /// 参考 B 站接口文档：https://github.com/SocialSisterYi/bilibili-API-collect
  static const Map<int, String> qualityIdNames = {
    127: '8K',
    120: '4K',
    116: '1080P60',
    112: '1080P+',
    80: '1080P',
    74: '720P60',
    64: '720P',
    32: '480P',
    16: '360P',
    6: '240P',
  };

  /// 画质 quality 优先级（整数，从高到低）
  static const List<int> qualityIdPriority = [
    120, // 4K
    116, // 1080P60
    112, // 1080P+
    80, // 1080P
    74, // 720P60
    64, // 720P
    32, // 480P
    16, // 360P
  ];

  // 存储
  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyCookies = 'bilibili_cookies';
  static const String prefKeyLoginEnabled = 'bilibili_enabled';
  static const String prefKeyDownloadDir = 'download_dir';
  static const String prefKeyMaxJobs = 'max_jobs';
  static const String prefKeyQuality = 'preferred_quality';
}
