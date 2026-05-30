import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Bilibili WBI 签名工具
class WbiSign {
  static final List<int> _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  static String _getMixinKey(String imgUrl, String subUrl) {
    String lookup = '';
    for (final url in [imgUrl, subUrl]) {
      final filename = url.split('/').last.split('.').first;
      lookup += filename;
    }
    String key = '';
    for (final i in _mixinKeyEncTab) {
      if (i < lookup.length) {
        key += lookup[i];
      }
    }
    return key.substring(0, 32);
  }

  static String _sanitize(String value) {
    return value.replaceAll(RegExp(r"[!'()*]"), '');
  }

  static Map<String, String> sign(
      Map<String, dynamic> params, String imgUrl, String subUrl) {
    final mixinKey = _getMixinKey(imgUrl, subUrl);
    final wts = (DateTime.now().millisecondsSinceEpoch / 1000).round().toString();

    final sortedParams = <String, String>{};
    for (final entry in params.entries) {
      sortedParams[entry.key] = _sanitize(entry.value.toString());
    }
    sortedParams['wts'] = wts;
    final sortedKeys = sortedParams.keys.toList()..sort();

    final query = sortedKeys.map((k) => '$k=${sortedParams[k]}').join('&');
    final signStr = md5.convert(utf8.encode('$query$mixinKey')).toString();

    sortedParams['w_rid'] = signStr;
    return sortedParams;
  }
}
