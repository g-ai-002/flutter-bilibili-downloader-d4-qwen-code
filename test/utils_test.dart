import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_downloader/utils/constants.dart';
import 'package:bilibili_downloader/utils/wbi_sign.dart';
import 'package:bilibili_downloader/services/bilibili_api.dart';
import 'package:bilibili_downloader/services/download_service.dart';

void main() {
  group('AppConstants', () {
    test('version is set', () {
      expect(AppConstants.version, isNotEmpty);
    });

    test('quality priority is ordered from high to low', () {
      expect(AppConstants.qualityPriority.first, '4K');
      expect(AppConstants.qualityPriority.last, '360P');
    });

    test('qualityIdPriority is ordered from high to low and starts at 120(4K)', () {
      expect(AppConstants.qualityIdPriority.first, 120);
      for (int i = 1; i < AppConstants.qualityIdPriority.length; i++) {
        expect(
          AppConstants.qualityIdPriority[i] <
              AppConstants.qualityIdPriority[i - 1],
          isTrue,
          reason: 'qualityIdPriority must be strictly descending',
        );
      }
    });

    test('qualityIdNames covers all priority ids', () {
      for (final id in AppConstants.qualityIdPriority) {
        expect(AppConstants.qualityIdNames.containsKey(id), isTrue,
            reason: 'missing name for quality id $id');
      }
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

  group('BilibiliApiException', () {
    test('toString returns message', () {
      final e = BilibiliApiException('请登录账号', code: -101);
      expect(e.toString(), '请登录账号');
      expect(e.code, -101);
    });

    test('message is preserved when code is null', () {
      final e = BilibiliApiException('网络错误');
      expect(e.code, isNull);
      expect(e.message, '网络错误');
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

  group('DownloadService.calcCumulativeTotal', () {
    test('both positive returns sum', () {
      expect(DownloadService.calcCumulativeTotal(100, 50), 150);
    });

    test('first positive, second zero returns first', () {
      expect(DownloadService.calcCumulativeTotal(100, 0), 100);
    });

    test('first zero, second positive returns second', () {
      expect(DownloadService.calcCumulativeTotal(0, 50), 50);
    });

    test('first positive, second negative returns first', () {
      expect(DownloadService.calcCumulativeTotal(100, -1), 100);
    });

    test('first negative, second positive returns second', () {
      expect(DownloadService.calcCumulativeTotal(-1, 50), 50);
    });

    test('both zero returns zero', () {
      expect(DownloadService.calcCumulativeTotal(0, 0), 0);
    });

    test('both negative returns zero', () {
      expect(DownloadService.calcCumulativeTotal(-1, -1), 0);
    });
  });
}
