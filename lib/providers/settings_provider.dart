import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/log_service.dart';

/// 设置状态管理
class SettingsProvider extends ChangeNotifier {
  StorageService? _storage;
  bool _darkMode = false;
  bool _bilibiliEnabled = false;
  String? _bilibiliCookies;
  String _preferredQuality = '1080P';
  int _maxJobs = 50;

  bool get darkMode => _darkMode;
  bool get bilibiliEnabled => _bilibiliEnabled;
  String? get bilibiliCookies => _bilibiliCookies;
  String get preferredQuality => _preferredQuality;
  int get maxJobs => _maxJobs;

  Future<void> load() async {
    try {
      _storage = await StorageService.instance;
      _darkMode = _storage!.darkMode;
      _bilibiliEnabled = _storage!.bilibiliEnabled;
      _bilibiliCookies = _storage!.bilibiliCookies;
      _preferredQuality = _storage!.preferredQuality;
      _maxJobs = _storage!.maxJobs;
      notifyListeners();
    } catch (e) {
      LogService.error('加载设置失败', e);
    }
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    _storage?.darkMode = value;
    notifyListeners();
  }

  Future<void> setBilibiliCookies(String? cookies) async {
    _bilibiliCookies = cookies;
    _bilibiliEnabled = cookies != null && cookies.isNotEmpty;
    _storage?.bilibiliCookies = cookies;
    _storage?.bilibiliEnabled = _bilibiliEnabled;
    notifyListeners();
  }

  Future<void> setPreferredQuality(String quality) async {
    _preferredQuality = quality;
    _storage?.preferredQuality = quality;
    notifyListeners();
  }

  Future<void> setMaxJobs(int value) async {
    _maxJobs = value;
    _storage?.maxJobs = value;
    notifyListeners();
  }
}
