import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_downloader/utils/constants.dart';
import 'package:bilibili_downloader/utils/wbi_sign.dart';

void main() {
  group('AppConstants', () {
    test('version is set', () {
      expect(AppConstants.version, isNotEmpty);
    });

    test('quality priority is ordered from high to low', () {
      expect(AppConstants.qualityPriority.first, '4K');
      expect(AppConstants.qualityPriority.last, '360P');
    });

    test('API URLs are valid', () {
      expect(AppConstants.bilibiliBaseUrl, startsWith('https://'));
      expect(AppConstants.bilibiliPassportUrl, startsWith('https://'));
      expect(AppConstants.bilibiliWwwUrl, startsWith('https://'));
    });

    test('download configs are positive', () {
      expect(AppConstants.maxConcurrentDownloads, greaterThan(0));
      expect(AppConstants.maxRetries, greaterThan(0));
      expect(AppConstants.maxJobs, greaterThan(0));
    });
  });

  group('WbiSign', () {
    test('sign produces wts and w_rid', () {
      final params = <String, dynamic>{
        'bvid': 'BV1xx',
        'cid': '123',
      };
      final imgUrl = 'https://i0.hdslb.com/bfs/wbi/7cd084941338484a.png';
      final subUrl = 'https://i0.hdslb.com/bfs/wbi/4932caff0ff4eab7.png';

      final result = WbiSign.sign(params, imgUrl, subUrl);

      expect(result, containsKey('wts'));
      expect(result, containsKey('w_rid'));
      expect(result['w_rid']!.length, 32); // MD5 hex
    });

    test('sign preserves original params', () {
      final params = <String, dynamic>{
        'bvid': 'BV1xx',
        'cid': '123',
      };
      final imgUrl = 'https://i0.hdslb.com/bfs/wbi/7cd084941338484a.png';
      final subUrl = 'https://i0.hdslb.com/bfs/wbi/4932caff0ff4eab7.png';

      final result = WbiSign.sign(params, imgUrl, subUrl);

      expect(result['bvid'], 'BV1xx');
      expect(result['cid'], '123');
    });

    test('sign handles special characters in params', () {
      final params = <String, dynamic>{
        'keyword': "test!'()*value",
      };
      final imgUrl = 'https://i0.hdslb.com/bfs/wbi/7cd084941338484a.png';
      final subUrl = 'https://i0.hdslb.com/bfs/wbi/4932caff0ff4eab7.png';

      final result = WbiSign.sign(params, imgUrl, subUrl);

      expect(result, containsKey('w_rid'));
      // Special characters should be sanitized
      expect(result['keyword'], 'testvalue');
    });
  });
}
