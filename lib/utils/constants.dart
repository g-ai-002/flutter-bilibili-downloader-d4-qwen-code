/// 应用常量

class AppConstants {
  static const String appName = 'Bilibili 下载器';
  static const String version = '0.2.2';

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

  // 画质优先级 (从高到低)
  static const List<String> qualityPriority = [
    '4K',
    '1080P+',
    '1080P',
    '720P+',
    '720P',
    '480P',
    '360P',
  ];

  // 存储
  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeyCookies = 'bilibili_cookies';
  static const String prefKeyLoginEnabled = 'bilibili_enabled';
  static const String prefKeyDownloadDir = 'download_dir';
  static const String prefKeyMaxJobs = 'max_jobs';
  static const String prefKeyQuality = 'preferred_quality';
}
