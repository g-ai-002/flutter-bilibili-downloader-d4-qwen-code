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
      expect(restored.status, job.status);
      expect(restored.progress, job.progress);
    });

    test('status labels are correct', () {
      expect(DownloadStatus.queued.label, '等待中');
      expect(DownloadStatus.downloading.label, '下载中');
      expect(DownloadStatus.completed.label, '已完成');
      expect(DownloadStatus.failed.label, '失败');
      expect(DownloadStatus.canceled.label, '已取消');
    });
  });
}
