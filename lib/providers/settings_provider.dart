import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../services/bilibili_api.dart';
import '../services/storage_service.dart';
import '../services/log_service.dart';

/// 设置状态管理
class SettingsProvider extends ChangeNotifier {
  StorageService? _storage;
  bool _darkMode = false;
  bool _bilibiliEnabled = false;
  String? _bilibiliCookies;
  String _preferredQuality = '4K';
  int _maxJobs = 50;
  BiliUserInfo? _userInfo;

  bool get darkMode => _darkMode;
  bool get bilibiliEnabled => _bilibiliEnabled;
  String? get bilibiliCookies => _bilibiliCookies;
  String get preferredQuality => _preferredQuality;
  int get maxJobs => _maxJobs;
  BiliUserInfo? get userInfo => _userInfo;

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
    if (!_bilibiliEnabled) {
      _userInfo = null;
    }
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

  /// 刷新当前登录用户信息
  Future<void> refreshUserInfo(BilibiliApi api) async {
    if (!_bilibiliEnabled) {
      if (_userInfo != null) {
        _userInfo = null;
        notifyListeners();
      }
      return;
    }
    final info = await api.getUserInfo();
    if (info != null) {
      _userInfo = info;
      notifyListeners();
    } else {
      // cookies 已失效
      _userInfo = null;
      notifyListeners();
    }
  }
}
