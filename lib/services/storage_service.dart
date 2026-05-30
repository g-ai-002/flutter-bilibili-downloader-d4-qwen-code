import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 本地存储服务
class StorageService {
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    _instance ??= StorageService._();
    await _instance!._init();
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- 主题 ---
  bool get darkMode => _prefs.getBool(AppConstants.prefKeyDarkMode) ?? false;
  set darkMode(bool value) => _prefs.setBool(AppConstants.prefKeyDarkMode, value);

  // --- Bilibili Cookies ---
  String? get bilibiliCookies => _prefs.getString(AppConstants.prefKeyCookies);
  set bilibiliCookies(String? value) {
    if (value != null && value.isNotEmpty) {
      _prefs.setString(AppConstants.prefKeyCookies, value);
    } else {
      _prefs.remove(AppConstants.prefKeyCookies);
    }
  }

  bool get bilibiliEnabled => _prefs.getBool(AppConstants.prefKeyLoginEnabled) ?? false;
  set bilibiliEnabled(bool value) => _prefs.setBool(AppConstants.prefKeyLoginEnabled, value);

  // --- 下载设置 ---
  String get downloadDir => _prefs.getString(AppConstants.prefKeyDownloadDir) ?? '';
  set downloadDir(String value) => _prefs.setString(AppConstants.prefKeyDownloadDir, value);

  int get maxJobs => _prefs.getInt(AppConstants.prefKeyMaxJobs) ?? AppConstants.maxJobs;
  set maxJobs(int value) => _prefs.setInt(AppConstants.prefKeyMaxJobs, value);

  String get preferredQuality => _prefs.getString(AppConstants.prefKeyQuality) ?? '1080P';
  set preferredQuality(String value) => _prefs.setString(AppConstants.prefKeyQuality, value);

  // --- 搜索历史 ---
  Future<List<String>> getSearchHistory() async {
    final json = _prefs.getString('search_history');
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
    await _prefs.setString('search_history', jsonEncode(history));
  }

  Future<void> clearSearchHistory() async {
    await _prefs.remove('search_history');
  }

  Future<void> removeSearchHistory(String keyword) async {
    final history = await getSearchHistory();
    history.remove(keyword);
    await _prefs.setString('search_history', jsonEncode(history));
  }

  // --- 下载历史 ---
  Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    final json = _prefs.getString('download_history');
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveDownloadHistory(List<Map<String, dynamic>> history) async {
    await _prefs.setString('download_history', jsonEncode(history));
  }
}
