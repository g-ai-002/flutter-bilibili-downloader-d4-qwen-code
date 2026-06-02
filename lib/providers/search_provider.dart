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
  int _currentPage = 1;
  bool _hasMore = true;
  int _uploaderPage = 1;
  bool _hasMoreUploaders = true;

  BilibiliApi? get api => _api;
  List<BiliVideo> get results => _results;
  List<BiliUploader> get uploaderResults => _uploaderResults;
  BiliVideoDetail? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get keyword => _keyword;
  bool get hasMore => _hasMore;
  bool get hasMoreUploaders => _hasMoreUploaders;

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
    _currentPage = page;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _results = await _api!.search(keyword, page: page);
      _hasMore = _results.length >= 20;
    } catch (e) {
      _error = '搜索失败: $e';
      LogService.error('搜索失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载更多视频搜索结果
  Future<void> loadMore() async {
    if (_api == null || !_hasMore || _isLoading) return;
    _currentPage++;
    _isLoading = true;
    notifyListeners();

    try {
      final more = await _api!.search(_keyword, page: _currentPage);
      if (more.isEmpty) {
        _hasMore = false;
      } else {
        _results = [..._results, ...more];
        _hasMore = more.length >= 20;
      }
    } catch (e) {
      _currentPage--;
      LogService.error('加载更多失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 搜索 UP 主
  Future<void> searchUploaders(String keyword, {int page = 1}) async {
    if (_api == null) return;
    _keyword = keyword;
    _uploaderPage = page;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _uploaderResults = await _api!.searchUploaders(keyword, page: page);
      _hasMoreUploaders = _uploaderResults.length >= 20;
    } catch (e) {
      _error = '搜索 UP 主失败: $e';
      LogService.error('搜索 UP 主失败', e);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载更多 UP 主搜索结果
  Future<void> loadMoreUploaders() async {
    if (_api == null || !_hasMoreUploaders || _isLoading) return;
    _uploaderPage++;
    _isLoading = true;
    notifyListeners();

    try {
      final more = await _api!.searchUploaders(_keyword, page: _uploaderPage);
      if (more.isEmpty) {
        _hasMoreUploaders = false;
      } else {
        _uploaderResults = [..._uploaderResults, ...more];
        _hasMoreUploaders = more.length >= 20;
      }
    } catch (e) {
      _uploaderPage--;
      LogService.error('加载更多 UP 主失败', e);
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
      // detail() 内部 catch 异常后返回 null，但不会向外抛异常，
      // 此处显式检测 null 并将错误信息透传给 UI，避免无限加载骨架屏。
      if (_detail == null && _error == null) {
        _error = '获取视频详情失败：服务端返回异常，请稍后重试';
      }
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
    _currentPage = 1;
    _hasMore = true;
    _uploaderPage = 1;
    _hasMoreUploaders = true;
    notifyListeners();
  }
}
