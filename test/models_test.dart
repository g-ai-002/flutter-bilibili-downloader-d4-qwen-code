import 'package:flutter_test/flutter_test.dart';
import 'package:bilibili_downloader/models/video.dart';
import 'package:bilibili_downloader/models/download_job.dart';

void main() {
  group('BiliVideo', () {
    test('fromJson creates correct object', () {
      final json = {
        'bvid': 'BV1GJ411x7',
        'title': '测试视频',
        'pic': 'https://example.com/pic.jpg',
        'uploader': '测试UP主',
        'duration': '10:00',
        'view_count': '1.2万',
        'pubdate': '1234567890',
      };
      final video = BiliVideo.fromJson(json);
      expect(video.bvid, 'BV1GJ411x7');
      expect(video.title, '测试视频');
      expect(video.uploader, '测试UP主');
      expect(video.pic, 'https://example.com/pic.jpg');
      expect(video.duration, '10:00');
      expect(video.viewCount, '1.2万');
      expect(video.pubdate, '1234567890');
    });

    test('fromJson handles empty fields', () {
      final json = <String, dynamic>{};
      final video = BiliVideo.fromJson(json);
      expect(video.bvid, '');
      expect(video.title, '');
      expect(video.pic, '');
      expect(video.uploader, '');
      expect(video.duration, '');
      expect(video.viewCount, '');
      expect(video.pubdate, '');
    });

    test('toJson produces correct map', () {
      final video = BiliVideo(
        bvid: 'BV1GJ411x7',
        title: '测试视频',
        pic: 'https://example.com/pic.jpg',
        uploader: '测试UP主',
        duration: '10:00',
        viewCount: '1.2万',
        pubdate: '1234567890',
      );
      final json = video.toJson();
      expect(json['bvid'], 'BV1GJ411x7');
      expect(json['title'], '测试视频');
      expect(json['pic'], 'https://example.com/pic.jpg');
      expect(json['uploader'], '测试UP主');
      expect(json['duration'], '10:00');
      expect(json['view_count'], '1.2万');
      expect(json['pubdate'], '1234567890');
    });
  });

  group('BiliVideoDetail', () {
    test('creates with all fields', () {
      final detail = BiliVideoDetail(
        bvid: 'BV1xx',
        title: '测试详情',
        pic: 'https://example.com/pic.jpg',
        desc: '视频描述',
        uploader: 'UP主',
        duration: 300,
        episodes: [
          BiliEpisode(page: 1, name: '第1P', cid: 1001, bvid: 'BV1xx', url: 'https://bilibili.com/video/BV1xx?p=1'),
        ],
        formats: [
          BiliVideoFormat(formatId: '80', ext: 'mp4', quality: '1080P', width: 1920, height: 1080, hasVideo: true, hasAudio: true),
        ],
      );
      expect(detail.bvid, 'BV1xx');
      expect(detail.title, '测试详情');
      expect(detail.episodes.length, 1);
      expect(detail.formats.length, 1);
      expect(detail.formats.first.quality, '1080P');
    });
  });

  group('BiliEpisode', () {
    test('creates with optional cid', () {
      final ep = BiliEpisode(page: 1, name: '第1P', bvid: 'BV1xx', url: 'https://bilibili.com/video/BV1xx?p=1');
      expect(ep.cid, isNull);
      expect(ep.page, 1);
    });
  });

  group('BiliVideoFormat', () {
    test('creates with all fields', () {
      final format = BiliVideoFormat(
        formatId: '120', ext: 'mp4', quality: '4K', width: 3840, height: 2160, hasVideo: true, hasAudio: false,
      );
      expect(format.formatId, '120');
      expect(format.quality, '4K');
      expect(format.width, 3840);
      expect(format.height, 2160);
      expect(format.hasVideo, isTrue);
      expect(format.hasAudio, isFalse);
    });
  });

  group('BiliUploader', () {
    test('creates with all fields', () {
      final uploader = BiliUploader(mid: 12345, name: 'UP主', face: 'https://example.com/face.jpg', fans: '100万', sign: '签名');
      expect(uploader.mid, 12345);
      expect(uploader.name, 'UP主');
      expect(uploader.fans, '100万');
    });
  });

  group('DownloadJob', () {
    test('toJson and fromJson round trip', () {
      final job = DownloadJob(
        id: 'test_1',
        videoName: '测试视频',
        episodeName: '第1P',
        bvid: 'BV1GJ411x7',
        formatId: '80',
        quality: '1080P',
        status: DownloadStatus.downloading,
        progress: 50,
        downloadedBytes: 1024,
        totalBytes: 2048,
      );
      final json = job.toJson();
      final restored = DownloadJob.fromJson(json);
      expect(restored.id, job.id);
      expect(restored.videoName, job.videoName);
      expect(restored.episodeName, job.episodeName);
      expect(restored.bvid, job.bvid);
      expect(restored.formatId, job.formatId);
      expect(restored.quality, job.quality);
      expect(restored.status, job.status);
      expect(restored.progress, job.progress);
      expect(restored.downloadedBytes, job.downloadedBytes);
      expect(restored.totalBytes, job.totalBytes);
    });

    test('fromJson handles null fields', () {
      final json = {
        'id': 'test_1',
        'videoName': '测试视频',
        'episodeName': '第1P',
        'bvid': 'BV1xx',
        'formatId': '80',
        'quality': '1080P',
        'status': 'queued',
        'createdAt': '2024-01-01T00:00:00.000',
      };
      final job = DownloadJob.fromJson(json);
      expect(job.id, 'test_1');
      expect(job.error, isNull);
      expect(job.startedAt, isNull);
      expect(job.finishedAt, isNull);
      expect(job.progress, 0);
      expect(job.retryCount, 0);
    });

    test('status labels are correct', () {
      expect(DownloadStatus.queued.label, '等待中');
      expect(DownloadStatus.downloading.label, '下载中');
      expect(DownloadStatus.completed.label, '已完成');
      expect(DownloadStatus.failed.label, '失败');
      expect(DownloadStatus.canceled.label, '已取消');
    });

    test('speedText formats correctly', () {
      final job = DownloadJob(
        id: 'test_1',
        videoName: '测试',
        episodeName: 'P1',
        bvid: 'BV1xx',
        formatId: '80',
        quality: '1080P',
        speed: 1024 * 1024, // 1 MB/s
      );
      expect(job.speedText, '1.0 MB/s');

      job.speed = 500 * 1024; // 500 KB/s
      expect(job.speedText, '500.0 KB/s');

      job.speed = 0;
      expect(job.speedText, '');
    });

    test('duration formats correctly', () {
      final now = DateTime.now();
      final job = DownloadJob(
        id: 'test_1',
        videoName: '测试',
        episodeName: 'P1',
        bvid: 'BV1xx',
        formatId: '80',
        quality: '1080P',
        startedAt: now.subtract(const Duration(hours: 1, minutes: 30, seconds: 15)),
      );
      expect(job.duration, isNotEmpty);
    });

    test('duration returns empty when not started', () {
      final job = DownloadJob(
        id: 'test_1',
        videoName: '测试',
        episodeName: 'P1',
        bvid: 'BV1xx',
        formatId: '80',
        quality: '1080P',
      );
      expect(job.duration, '');
    });
  });
}
