import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../services/bilibili_api.dart';
import '../services/log_service.dart';

/// 搜索状态管理
class SearchProvider extends ChangeNotifier {
  BilibiliApi? _api;
  List<BiliVideo> _results = [];
  List<BiliUploader> _uploaderResults = [];
  BiliVideoDetail? _detail;
  bool _isLoading = false;
  String? _error;
  String _keyword = '';

  BilibiliApi? get api => _api;
  List<BiliVideo> get results => _results;
  List<BiliUploader> get uploaderResults => _uploaderResults;
  BiliVideoDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get keyword => _keyword;

  void initApi(BilibiliApi api) {
    _api = api;
  }

  void updateCookies(String? cookies) {
    _api?.updateCookies(cookies);
  }

  /// 搜索视频
  Future<void> search(String keyword, {int page = 1}) async {
    if (_api == null) return;
    _keyword = keyword;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _results = await _api!.search(keyword, page: page);
    } catch (e) {
      _error = '搜索失败: $e';
      LogService.error('搜索失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 搜索 UP 主
  Future<void> searchUploaders(String keyword) async {
    if (_api == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _uploaderResults = await _api!.searchUploaders(keyword);
    } catch (e) {
      _error = '搜索 UP 主失败: $e';
      LogService.error('搜索 UP 主失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 获取视频详情
  Future<void> loadDetail(String bvid) async {
    if (_api == null) return;
    _detail = null; // 先清空旧数据
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _detail = await _api!.detail(bvid);
    } catch (e) {
      _error = '获取详情失败: $e';
      LogService.error('获取详情失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 清除视频详情（切换页面时避免显示上一个视频的残留数据）
  void clearDetail() {
    _detail = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// 获取 UP 主视频
  Future<void> loadUploaderVideos(int mid) async {
    if (_api == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _results = await _api!.getUploaderVideos(mid);
    } catch (e) {
      _error = '获取 UP 主视频失败: $e';
      LogService.error('获取 UP 主视频失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearResults() {
    _results = [];
    _uploaderResults = [];
    _detail = null;
    _error = null;
    notifyListeners();
  }
}
