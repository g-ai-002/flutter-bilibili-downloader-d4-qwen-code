import 'dart:convert';
import 'package:dio/dio.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// Bilibili 扫码登录服务
class BilibiliLogin {
  late final Dio _dio;
  String? _qrcodeKey;

  BilibiliLogin() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.bilibiliPassportUrl,
      headers: {
        'User-Agent': AppConstants.userAgent,
        'Referer': 'https://www.bilibili.com/',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  /// 获取登录二维码
  Future<LoginQrCode> getQrCode() async {
    try {
      final resp = await _dio.get('/x/passport-login/web/qrcode/generate');
      final data = resp.data;
      if (data['code'] != 0) {
        return LoginQrCode(
          success: false,
          message: data['message'] ?? '获取二维码失败',
        );
      }
      _qrcodeKey = data['data']['qrcode_key'];
      return LoginQrCode(
        success: true,
        url: data['data']['url'] ?? '',
        qrcodeKey: _qrcodeKey!,
        message: '请使用 Bilibili APP 扫码登录',
      );
    } catch (e) {
      LogService.error('获取二维码失败', e);
      return LoginQrCode(success: false, message: '网络错误，请重试');
    }
  }

  /// 检查扫码状态
  Future<LoginResult> checkLogin({String? qrcodeKey}) async {
    final key = qrcodeKey ?? _qrcodeKey;
    if (key == null) {
      return LoginResult(success: false, message: '请先获取二维码');
    }

    try {
      final resp = await _dio.get('/x/passport-login/web/qrcode/poll', queryParameters: {
        'qrcode_key': key,
      });
      final data = resp.data;
      final code = data['data']['code'] as int? ?? -1;

      if (code == 0) {
        // 登录成功，提取 cookies
        final cookies = _extractCookies(resp);
        if (!cookies.contains('SESSDATA=')) {
          return LoginResult(success: false, message: '登录成功但未获取到有效 Cookies');
        }
        return LoginResult(success: true, cookies: cookies, message: '登录成功！');
      }

      final messages = {
        86090: '已扫码，请在手机上点击「确认登录」',
        86101: '未扫码，请用 Bilibili APP 扫码',
        86102: '已取消，请重新扫码',
        86038: '二维码已失效，请重新获取',
      };

      return LoginResult(
        success: false,
        message: messages[code] ?? data['data']['message'] ?? '状态码: $code',
      );
    } catch (e) {
      LogService.error('检查登录状态失败', e);
      return LoginResult(success: false, message: '网络错误');
    }
  }

  String _extractCookies(Response resp) {
    final parts = <String>[];
    resp.headers.forEach((name, values) {
      if (name.toLowerCase() == 'set-cookie') {
        for (final value in values) {
          final cookie = value.split(';').first;
          if (cookie.contains('=')) {
            parts.add(cookie);
          }
        }
      }
    });
    return parts.join('; ');
  }
}

class LoginQrCode {
  final bool success;
  final String url;
  final String qrcodeKey;
  final String message;

  LoginQrCode({
    required this.success,
    this.url = '',
    this.qrcodeKey = '',
    this.message = '',
  });
}

class LoginResult {
  final bool success;
  final String cookies;
  final String message;

  LoginResult({
    required this.success,
    this.cookies = '',
    this.message = '',
  });
}
