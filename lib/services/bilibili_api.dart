import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/video.dart';
import '../utils/constants.dart';
import '../utils/wbi_sign.dart';
import 'log_service.dart';
import 'storage_service.dart';

/// 业务可读的接口错误（用于将 412 风控等技术错误转成给用户看的提示）
class BilibiliApiException implements Exception {
  final String message;
  final int? code;
  BilibiliApiException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Bilibili API 客户端
class BilibiliApi {
  late final Dio _dio;
  String? _cookies;
  String? _wbiImgUrl;
  String? _wbiSubUrl;
  DateTime? _wbiKeyFetchTime;
  String? _buvid3;
  bool _buvidPrepared = false;

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
      // 412 等错误不直接抛异常，由调用方根据 code/状态自行处理。
      validateStatus: (status) => status != null && status < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final merged = _composeCookies();
        if (merged.isNotEmpty) {
          options.headers['Cookie'] = merged;
        }
        handler.next(options);
      },
    ));
  }

  void updateCookies(String? cookies) {
    _cookies = cookies;
  }

  String _composeCookies() {
    final parts = <String>[];
    if (_cookies != null && _cookies!.isNotEmpty) parts.add(_cookies!);
    if (_buvid3 != null && _buvid3!.isNotEmpty && !(_cookies?.contains('buvid3=') ?? false)) {
      parts.add('buvid3=${_buvid3!}');
    }
    return parts.join('; ');
  }

  /// 通过访问 www.bilibili.com 获取 `buvid3` cookie，
  /// 这是解决搜索接口 412(风控) 的关键之一。
  /// 会优先从本地存储加载已缓存的 buvid3，仅首次或缓存不存在时请求。
  Future<void> _ensureBuvid() async {
    if (_buvidPrepared) return;
    _buvidPrepared = true;

    // 尝试从本地存储加载已缓存的 buvid3
    try {
      final storage = await StorageService.instance;
      final cached = storage.cachedBuvid3;
      if (cached != null && cached.isNotEmpty) {
        _buvid3 = cached;
        return;
      }
    } catch (_) {}

    try {
      final tmp = Dio(BaseOptions(
        headers: {
          'User-Agent': AppConstants.userAgent,
          'Referer': 'https://www.bilibili.com/',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (s) => s != null && s < 500,
      ));
      final resp = await tmp.get('https://www.bilibili.com/');
      final cookies = resp.headers.map['set-cookie'] ?? const <String>[];
      for (final raw in cookies) {
        final m = RegExp(r'buvid3=([^;]+)').firstMatch(raw);
        if (m != null) {
          _buvid3 = m.group(1);
          // 持久化 buvid3
          try {
            final storage = await StorageService.instance;
            storage.cachedBuvid3 = _buvid3;
          } catch (_) {}
          break;
        }
      }
      tmp.close(force: true);
    } catch (e) {
      LogService.warning('获取 buvid3 失败（将继续以匿名方式访问）: $e');
    }
  }

  /// 获取 WBI 密钥（带重试，且会在风控时刷新 buvid3）
  Future<void> _ensureWbiKey() async {
    if (_wbiKeyFetchTime != null &&
        DateTime.now().difference(_wbiKeyFetchTime!).inSeconds < 600) {
      return;
    }
    await _ensureBuvid();
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final resp = await _dio.get('/x/web-interface/nav');
        final data = resp.data;
        if (data is Map && data['code'] == 0) {
          final wbiImg = data['data']['wbi_img'] ?? {};
          _wbiImgUrl = wbiImg['img_url'] ?? '';
          _wbiSubUrl = wbiImg['sub_url'] ?? '';
          _wbiKeyFetchTime = DateTime.now();
          return;
        }
        // 部分账号未登录时 nav 仍返回 wbi_img，可继续；其它情况记录后重试
      } catch (e) {
        LogService.error('获取 WBI 密钥失败(第${attempt + 1}次)', e);
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << attempt));
        }
      }
    }
  }

  /// 搜索视频
  Future<List<BiliVideo>> search(String keyword, {int page = 1, int pageSize = 20}) async {
    try {
      await _ensureWbiKey();
      final params = {
        'search_type': 'video',
        'keyword': keyword,
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'order': 'pubdate',
      };
      final signed = _wbiImgUrl != null && _wbiSubUrl != null
          ? WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!)
          : params;
      final resp = await _dio.get('/x/web-interface/search/type', queryParameters: signed);
      if (resp.statusCode == 412) {
        throw BilibiliApiException('请求被 B 站风控拦截(412)，请稍后再试，或扫码登录后重试。', code: 412);
      }
      final data = resp.data;
      if (data is! Map || data['code'] != 0) {
        final msg = (data is Map ? data['message']?.toString() : null) ?? '搜索失败';
        throw BilibiliApiException(msg, code: data is Map ? data['code'] as int? : null);
      }

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
          pubdate: _formatPubdate(item['pubdate']),
        ));
      }
      return results;
    } on BilibiliApiException {
      rethrow;
    } catch (e) {
      LogService.error('搜索视频失败', e);
      throw BilibiliApiException('搜索视频失败：$e');
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
        uploaderMid: v['owner']['mid'] as int? ?? 0,
        uploaderFace: _normalizePic(v['owner']['face'] as String? ?? ''),
        duration: v['duration'] as int? ?? 0,
        episodes: episodes,
        formats: formats,
        pubdate: v['pubdate'] as int? ?? 0,
      );
    } catch (e) {
      LogService.error('获取视频详情失败', e);
      return null;
    }
  }

  /// 获取视频可用画质
  Future<List<BiliVideoFormat>> _getFormats(String bvid, int cid) async {
    try {
      await _ensureWbiKey();
      final params = {
        'bvid': bvid,
        'cid': cid.toString(),
      };
      final signed = _wbiImgUrl != null && _wbiSubUrl != null
          ? WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!)
          : params;
      final resp = await _dio.get('/x/player/wbi/v2', queryParameters: signed);
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

  /// 获取视频播放 URL（优先单文件格式，DASH 作为回退）
  /// 失败时抛出 [BilibiliApiException]，便于下载层将原因透传给用户。
  Future<String?> getPlayUrl(String bvid, int cid, int quality) async {
    await _ensureWbiKey();
    if (_wbiImgUrl == null || _wbiSubUrl == null) {
      throw BilibiliApiException('WBI 签名密钥获取失败，请检查网络后重试');
    }

    // 优先尝试单文件格式（fnval=16: MP4 含音视频）
    final single = await _fetchPlayUrlSafe(bvid, cid, quality, '16');
    if (single.url != null) return single.url;

    // 回退到 DASH 格式
    final dash = await _fetchPlayUrlSafe(bvid, cid, quality, '4048');
    if (dash.url != null) return dash.url;

    // 两种都失败：综合两次结果给出尽量明确的错误
    final err = dash.error ?? single.error;
    if (err != null) {
      throw BilibiliApiException(err);
    }
    throw BilibiliApiException(
      '无法获取播放地址：可能需要登录或大会员（4K/1080P+ 需登录大会员），请前往设置中扫码登录后重试',
    );
  }

  /// 请求播放 URL，将技术错误归一化为 (url, error) 元组
  Future<_PlayUrlResult> _fetchPlayUrlSafe(
    String bvid,
    int cid,
    int quality,
    String fnval,
  ) async {
    try {
      final params = {
        'bvid': bvid,
        'cid': cid.toString(),
        'qn': quality.toString(),
        'fnval': fnval,
        'fnver': '0',
        'fourk': '1',
      };

      final signed = WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!);
      final resp = await _dio.get('/x/player/wbi/playurl', queryParameters: signed);
      if (resp.statusCode == 412) {
        return _PlayUrlResult.err('B 站风控拦截(412)，请稍后再试或登录后重试');
      }
      final data = resp.data;
      if (data is! Map || data['code'] != 0) {
        final code = data is Map ? data['code'] : null;
        final msg = data is Map ? (data['message']?.toString() ?? '') : '';
        // -101 未登录；-10403 大会员专享；87007/87008 充电视频
        if (code == -101) {
          return _PlayUrlResult.err('请先登录账号（部分画质/视频需要登录）');
        }
        if (code == -10403) {
          return _PlayUrlResult.err('当前画质需要大会员，请降级画质或开通大会员');
        }
        return _PlayUrlResult.err(msg.isEmpty ? '获取播放地址失败 (code=$code)' : msg);
      }

      // 单文件格式：返回 durl
      final durl = data['data']['durl'] as List<dynamic>? ?? [];
      if (durl.isNotEmpty) {
        final url = durl.first['url'] as String?;
        if (url != null && url.isNotEmpty) return _PlayUrlResult.ok(url);
      }

      // DASH 格式：返回视频+音频 URL
      final dash = data['data']['dash'];
      if (dash != null) {
        final video = dash['video'] as List<dynamic>? ?? [];
        final audio = dash['audio'] as List<dynamic>? ?? [];
        if (video.isNotEmpty && audio.isNotEmpty) {
          return _PlayUrlResult.ok(jsonEncode({
            'video': video.first['baseUrl'] ?? video.first['base_url'] ?? '',
            'audio': audio.first['baseUrl'] ?? audio.first['base_url'] ?? '',
          }));
        }
      }
      return _PlayUrlResult.err('响应中未包含可用的播放地址');
    } catch (e) {
      return _PlayUrlResult.err('请求播放地址异常: $e');
    }
  }

  /// 搜索 UP 主
  Future<List<BiliUploader>> searchUploaders(String keyword, {int page = 1}) async {
    try {
      await _ensureWbiKey();
      final params = {
        'search_type': 'bili_user',
        'keyword': keyword,
        'page': page.toString(),
      };
      final signed = _wbiImgUrl != null && _wbiSubUrl != null
          ? WbiSign.sign(params, _wbiImgUrl!, _wbiSubUrl!)
          : params;
      final resp = await _dio.get('/x/web-interface/search/type', queryParameters: signed);
      if (resp.statusCode == 412) {
        throw BilibiliApiException('请求被 B 站风控拦截(412)，请稍后再试，或扫码登录后重试。', code: 412);
      }
      final data = resp.data;
      if (data is! Map || data['code'] != 0) return [];

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
    } on BilibiliApiException {
      rethrow;
    } catch (e) {
      LogService.error('搜索 UP 主失败', e);
      throw BilibiliApiException('搜索 UP 主失败：$e');
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
          pubdate: _formatPubdate(item['created']),
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

  /// 获取当前登录用户信息 (uname / face / mid)
  /// 未登录或失败返回 null
  Future<BiliUserInfo?> getUserInfo() async {
    if (_cookies == null || _cookies!.isEmpty) return null;
    try {
      final resp = await _dio.get('/x/web-interface/nav');
      final data = resp.data;
      if (data['code'] != 0) return null;
      final d = data['data'] as Map<String, dynamic>;
      if (d['isLogin'] != true) return null;
      return BiliUserInfo(
        mid: d['mid'] as int? ?? 0,
        uname: d['uname'] as String? ?? '',
        face: _normalizePic(d['face'] as String? ?? ''),
        level: (d['level_info']?['current_level'] as int?) ?? 0,
      );
    } catch (e) {
      LogService.error('获取用户信息失败', e);
      return null;
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

  /// 将 Unix 时间戳（秒）格式化为 YYYY-MM-DD
  String _formatPubdate(dynamic ts) {
    if (ts == null) return '';
    try {
      final seconds = ts is int ? ts : int.tryParse(ts.toString()) ?? 0;
      if (seconds <= 0) return '';
      final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
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

/// 内部用于归一化 _fetchPlayUrlSafe 返回值的简单 Either。
class _PlayUrlResult {
  final String? url;
  final String? error;
  const _PlayUrlResult._(this.url, this.error);
  factory _PlayUrlResult.ok(String url) => _PlayUrlResult._(url, null);
  factory _PlayUrlResult.err(String err) => _PlayUrlResult._(null, err);
}
