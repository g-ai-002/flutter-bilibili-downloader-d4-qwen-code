import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_job.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 本地存储服务
///
/// 使用 `_initFuture` 缓存初始化 Future，避免并发调用 `instance` 时
/// 多次进入 `if (_instance == null)` 分支创建多个实例 / 多次 await
/// 同一个 SharedPreferences，导致 late 字段 `_prefs` 在另一个引用上未赋值
/// 触发 `LateInitializationError`（见 Issue #6 评论日志）。
class StorageService {
  static StorageService? _instance;
  static Future<StorageService>? _initFuture;

  SharedPreferences? _prefs;
  bool _initialized = false;

  StorageService._();

  static Future<StorageService> get instance {
    final cached = _initFuture;
    if (cached != null) return cached;
    final future = _bootstrap();
    _initFuture = future;
    return future;
  }

  static Future<StorageService> _bootstrap() async {
    final service = StorageService._();
    await service._init();
    _instance = service;
    return service;
  }

  /// 同步方式获取已初始化的实例。若尚未初始化返回 null（调用方需做好降级）。
  static StorageService? get instanceOrNull => _instance;

  Future<void> _init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// 内部统一访问 SharedPreferences；若未初始化则抛出清晰错误而非 LateInitializationError。
  SharedPreferences get _p {
    final p = _prefs;
    if (p == null) {
      throw StateError(
        'StorageService 尚未完成初始化，请通过 await StorageService.instance 获取实例后再访问。',
      );
    }
    return p;
  }

  // --- 主题 ---
  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  set darkMode(bool value) => _p.setBool(AppConstants.prefKeyDarkMode, value);

  // --- Bilibili Cookies ---
  String? get bilibiliCookies => _p.getString(AppConstants.prefKeyCookies);
  set bilibiliCookies(String? value) {
    if (value != null && value.isNotEmpty) {
      _p.setString(AppConstants.prefKeyCookies, value);
    } else {
      _p.remove(AppConstants.prefKeyCookies);
    }
  }

  bool get bilibiliEnabled => _p.getBool(AppConstants.prefKeyLoginEnabled) ?? false;
  set bilibiliEnabled(bool value) => _p.setBool(AppConstants.prefKeyLoginEnabled, value);

  // --- 下载设置 ---
  String get downloadDir => _p.getString(AppConstants.prefKeyDownloadDir) ?? '';
  set downloadDir(String value) => _p.setString(AppConstants.prefKeyDownloadDir, value);

  int get maxJobs => _p.getInt(AppConstants.prefKeyMaxJobs) ?? AppConstants.maxJobs;
  set maxJobs(int value) => _p.setInt(AppConstants.prefKeyMaxJobs, value);

  String get preferredQuality => _p.getString(AppConstants.prefKeyQuality) ?? '4K';
  set preferredQuality(String value) => _p.setString(AppConstants.prefKeyQuality, value);

  // --- 搜索历史 ---
  Future<List<String>> getSearchHistory() async {
    final json = _p.getString('search_history');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<String>();
    } catch (e) {
      return [];
    }
  }

  Future<void> addSearchHistory(String keyword) async {
    final history = await getSearchHistory();
    history.remove(keyword);
    history.insert(0, keyword);
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }
    await _p.setString('search_history', jsonEncode(history));
  }

  Future<void> clearSearchHistory() async {
    await _p.remove('search_history');
  }

  Future<void> removeSearchHistory(String keyword) async {
    final history = await getSearchHistory();
    history.remove(keyword);
    await _p.setString('search_history', jsonEncode(history));
  }

  // --- 下载历史 ---
  Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    final json = _p.getString('download_history');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDownloadHistory(List<Map<String, dynamic>> history) async {
    await _p.setString('download_history', jsonEncode(history));
  }

  /// 保存下载任务列表（持久化）
  Future<void> saveDownloadJobs(List<DownloadJob> jobs) async {
    final list = jobs.map((j) => j.toJson()).toList();
    await _p.setString('persisted_download_jobs', jsonEncode(list));
  }

  /// 加载持久化的下载任务列表
  Future<List<DownloadJob>> loadDownloadJobs() async {
    final json = _p.getString('persisted_download_jobs');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => DownloadJob.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      LogService.error('加载下载历史失败', e);
      return [];
    }
  }
}
