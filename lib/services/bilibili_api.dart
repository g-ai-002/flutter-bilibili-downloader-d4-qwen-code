import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/video.dart';
import '../utils/constants.dart';
import '../utils/wbi_sign.dart';
import 'log_service.dart';

/// Bilibili API 客户端
class BilibiliApi {
  late final Dio _dio;
  String? _cookies;
  String? _wbiImgUrl;
  String? _wbiSubUrl;
  DateTime? _wbiKeyFetchTime;

  BilibiliApi({String? cookies}) {
    _cookies = cookies;
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.bilibiliBaseUrl,
      headers: {
        'User-Agent': AppConstants.userAgent,
        'Referer': 'https://www.bilibili.com/',
        'Origin': 'https://www.bilibili.com',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_cookies != null && _cookies!.isNotEmpty) {
          options.headers['Cookie'] = _cookies;
        }
        handler.next(options);
      },
    ));
  }

  void updateCookies(String? cookies) {
    _cookies = cookies;
  }

  /// 获取 WBI 密钥
  Future<void> _ensureWbiKey() async {
    if (_wbiKeyFetchTime != null &&
        DateTime.now().difference(_wbiKeyFetchTime!).inSeconds < 600) {
      return;
    }
    try {
      final resp = await _dio.get('/x/web-interface/nav');
      final data = resp.data;
      if (data['code'] == 0) {
        final wbiImg = data['data']['wbi_img'] ?? {};
        _wbiImgUrl = wbiImg['img_url'] ?? '';
        _wbiSubUrl = wbiImg['sub_url'] ?? '';
        _wbiKeyFetchTime = DateTime.now();
      }
    } catch (e) {
      LogService.error('获取 WBI 密钥失败', e);
    }
  }

  /// 搜索视频
  Future<List<BiliVideo>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    try {
      final resp = await _dio.get('/x/web-interface/search/type', queryParameters: {
        'search_type': 'video',
        'keyword': keyword,
        'page': page,
        'page_size': pageSize,
      });
      final data = resp.data;
      if (data['code'] != 0) return [];

      final results = <BiliVideo>[];
      for (final item in data['data']['result'] as List<dynamic>) {
        final bvid = item['bvid'] as String? ?? '';
        if (bvid.isEmpty) continue;
        results.add(BiliVideo(
          bvid: bvid,
          title: _cleanHtml(item['title'] as String? ?? ''),
          pic: _normalizePic(item['pic'] as String? ?? ''),
          uploader: item['author'] as String? ?? '',
          duration: item['duration'] as String? ?? '',
          viewCount: _formatViewCount(item['play'] as int? ?? 0),
          pubdate: item['pubdate']?.toString() ?? '',
        ));
      }
      return results;
    } catch (e) {
      LogService.error('搜索视频失败', e);
      return [];
    }
  }

  /// 获取视频详情
  Future<BiliVideoDetail?> detail(String bvid) async {
    try {
      final resp = await _dio.get('/x/web-interface/view', queryParameters: {'bvid': bvid});
      final data = resp.data;
      if (data['code'] != 0) return null;

      final v = data['data'];
      final episodes = <BiliEpisode>[];
      final pages = v['pages'] as List<dynamic>? ?? [];
      for (final p in pages) {
        episodes.add(BiliEpisode(
          page: p['page'] as int? ?? 1,
          name: p['part'] as String? ?? '第${p['page']}P',
          cid: p['cid'] as int?,
          bvid: bvid,
          url: 'https://www.bilibili.com/video/$bvid?p=${p['page']}',
        ));
      }

      // 获取可用画质
      final formats = await _getFormats(bvid, episodes.first.cid ?? 0);

      return BiliVideoDetail(
        bvid: bvid,
        title: v['title'] as String? ?? '',
        pic: _normalizePic(v['pic'] as String? ?? ''),
        desc: v['desc'] as String? ?? '',
        uploader: v['owner']['name'] as String? ?? '',
        duration: v['duration'] as int? ?? 0,
        episodes: episodes,
        formats: formats,
      );
    } catch (e) {
      LogService.error('获取视频详情失败', e);
      return null;
    }
  }

  /// 获取视频可用画质
  Future<List<BiliVideoFormat>> _getFormats(String bvid, int cid) async {
    try {
      final resp = await _dio.get('/x/player/wbi/v2', queryParameters: {
        'bvid': bvid,
        'cid': cid,
      });
      final data = resp.data;
      if (data['code'] != 0) return [];

      final formats = <BiliVideoFormat>[];
      final supportFormats = data['data']['support_formats'] as List<dynamic>? ?? [];
      for (final f in supportFormats) {
        formats.add(BiliVideoFormat(
          formatId: f['quality'].toString(),
          ext: 'mp4',
          quality: f['new_description'] as String? ?? f['description'] as String? ?? '',
          width: null,
          height: null,
          hasVideo: true,
          hasAudio: true,
        ));
      }
      return formats;
    } catch (e) {
      LogService.error('获取视频画质失败', e);
      return [];
    }
  }

  /// 获取视频播放 URL
  Future<String?> getPlayUrl(String bvid, int cid, int quality) async {
    try {
      await _ensureWbiKey();
      if (_wbiImgUrl == null || _wbiSubUrl == null) return null;

      final params = {
        'bvid': bvid,
        'cid': cid.toString(),
        'qn': quality.toString(),
        'fnval': '4048', // DASH + HDR
        'fnver': '0',
        'fourk': '1',
      };

      final signed = WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!);
      final resp = await _dio.get('/x/player/wbi/playurl', queryParameters: signed);
      final data = resp.data;
      if (data['code'] != 0) return null;

      final dash = data['data']['dash'];
      if (dash != null) {
        final video = dash['video'] as List<dynamic>? ?? [];
        final audio = dash['audio'] as List<dynamic>? ?? [];
        if (video.isNotEmpty && audio.isNotEmpty) {
          // 返回最佳视频和音频 URL
          return jsonEncode({
            'video': video.first['baseUrl'] ?? video.first['base_url'] ?? '',
            'audio': audio.first['baseUrl'] ?? audio.first['base_url'] ?? '',
          });
        }
      }

      // 返回 DURL
      final durl = data['data']['durl'] as List<dynamic>? ?? [];
      if (durl.isNotEmpty) {
        return durl.first['url'] as String?;
      }

      return null;
    } catch (e) {
      LogService.error('获取播放 URL 失败', e);
      return null;
    }
  }

  /// 搜索 UP 主
  Future<List<BiliUploader>> searchUploaders(String keyword, {int page = 1}) async {
    try {
      final resp = await _dio.get('/x/web-interface/search/type', queryParameters: {
        'search_type': 'bili_user',
        'keyword': keyword,
        'page': page,
      });
      final data = resp.data;
      if (data['code'] != 0) return [];

      final results = <BiliUploader>[];
      for (final item in data['data']['result'] as List<dynamic>? ?? []) {
        final mid = item['mid'] as int? ?? 0;
        if (mid <= 0) continue;
        results.add(BiliUploader(
          mid: mid,
          name: _cleanHtml(item['uname'] as String? ?? ''),
          face: _normalizePic(item['upic'] as String? ?? ''),
          fans: _formatViewCount(item['fans'] as int? ?? 0),
          sign: _cleanHtml(item['usign'] as String? ?? ''),
        ));
      }
      return results;
    } catch (e) {
      LogService.error('搜索 UP 主失败', e);
      return [];
    }
  }

  /// 获取 UP 主视频列表
  Future<List<BiliVideo>> getUploaderVideos(int mid, {int page = 1, int pageSize = 30}) async {
    try {
      await _ensureWbiKey();
      if (_wbiImgUrl == null || _wbiSubUrl == null) return [];

      final params = {
        'mid': mid.toString(),
        'pn': page.toString(),
        'ps': pageSize.toString(),
        'order': 'pubdate',
      };
      final signed = WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!);
      final resp = await _dio.get('/x/space/wbi/arc/search', queryParameters: signed);
      final data = resp.data;
      if (data['code'] != 0) return [];

      final results = <BiliVideo>[];
      final vlist = data['data']['list']['vlist'] as List<dynamic>? ?? [];
      for (final item in vlist) {
        results.add(BiliVideo(
          bvid: item['bvid'] as String? ?? '',
          title: _cleanHtml(item['title'] as String? ?? ''),
          pic: _normalizePic(item['pic'] as String? ?? ''),
          uploader: item['author'] as String? ?? '',
          duration: _formatDuration(item['length'] as String? ?? '0'),
          viewCount: _formatViewCount(item['play'] as int? ?? 0),
          pubdate: item['created']?.toString() ?? '',
        ));
      }
      return results;
    } catch (e) {
      LogService.error('获取 UP 主视频列表失败', e);
      return [];
    }
  }

  /// 验证 Cookies 是否有效
  Future<bool> verifyCookies() async {
    if (_cookies == null || _cookies!.isEmpty) return false;
    try {
      final resp = await _dio.get('/x/web-interface/nav');
      final data = resp.data;
      return data['code'] == 0 && data['data']['isLogin'] == true;
    } catch (e) {
      return false;
    }
  }

  String _cleanHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  String _normalizePic(String url) {
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http:')) return url.replaceFirst('http:', 'https:');
    return url;
  }

  String _formatViewCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

  String _formatDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length == 3) {
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final s = int.parse(parts[2]);
      if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return duration;
  }
}
