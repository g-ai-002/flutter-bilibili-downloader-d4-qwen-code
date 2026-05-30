import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_job.dart';
import '../utils/constants.dart';
import 'bilibili_api.dart';
import 'log_service.dart';
import 'notification_service.dart';

/// 下载服务
class DownloadService {
  final BilibiliApi _api;
  final List<DownloadJob> _jobs = [];
  final Map<String, CancelToken> _cancelTokens = {};
  int _nextId = 1;
  int _activeCount = 0;
  final StreamController<DownloadJob> _jobController =
      StreamController<DownloadJob>.broadcast();

  DownloadService(this._api);

  Stream<DownloadJob> get jobStream => _jobController.stream;
  List<DownloadJob> get jobs => List.unmodifiable(_jobs);

  /// 添加下载任务
  DownloadJob addJob({
    required String videoName,
    required String episodeName,
    required String bvid,
    required int cid,
    required String formatId,
    required String quality,
  }) {
    final job = DownloadJob(
      id: '${_nextId++}_${DateTime.now().millisecondsSinceEpoch}',
      videoName: videoName,
      episodeName: episodeName,
      bvid: bvid,
      cid: cid,
      formatId: formatId,
      quality: quality,
    );
    _jobs.insert(0, job);
    _jobController.add(job);
    _processQueue();
    return job;
  }

  /// 处理下载队列
  void _processQueue() {
    while (_activeCount < AppConstants.maxConcurrentDownloads) {
      final pending =
          _jobs.where((j) => j.status == DownloadStatus.queued).toList();
      if (pending.isEmpty) break;
      _startDownload(pending.first);
    }
  }

  /// 开始下载
  Future<void> _startDownload(DownloadJob job) async {
    _activeCount++;
    job.status = DownloadStatus.downloading;
    job.startedAt = DateTime.now();
    _jobController.add(job);

    try {
      final playUrl = await _api.getPlayUrl(
        job.bvid,
        job.cid,
        int.tryParse(job.formatId) ?? 80,
      );

      if (playUrl == null) {
        throw Exception('无法获取播放地址');
      }

      // 解析播放 URL
      String videoUrl;
      String? audioUrl;

      try {
        final parsed = jsonDecode(playUrl);
        videoUrl = parsed['video'] as String;
        audioUrl = parsed['audio'] as String?;
      } catch (_) {
        videoUrl = playUrl;
      }

      // 创建下载目录
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory(
          '${dir.path}/downloads/${_safeFileName(job.videoName)}');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final isDASH = audioUrl != null && audioUrl.isNotEmpty;

      if (isDASH) {
        await _downloadDASH(job, videoUrl, audioUrl!, downloadDir);
      } else {
        await _downloadSingleFile(job, videoUrl, downloadDir);
      }

      job.status = DownloadStatus.completed;
      job.progress = 100;
      job.finishedAt = DateTime.now();
      NotificationService.instance
          .showDownloadComplete(job.videoName, job.episodeName);
    } catch (e) {
      await _handleDownloadError(job, e);
    }

    _activeCount--;
    _jobController.add(job);
    _processQueue();
  }

  /// 下载 DASH 格式（视频轨 + 音频轨，合并计算进度）
  Future<void> _downloadDASH(
    DownloadJob job,
    String videoUrl,
    String audioUrl,
    Directory downloadDir,
  ) async {
    final videoPath =
        '${downloadDir.path}/${_safeFileName(job.episodeName)}_video.mp4';
    final audioPath =
        '${downloadDir.path}/${_safeFileName(job.episodeName)}_audio.m4a';

    int videoTotal = 0;
    int audioTotal = 0;
    int cumulativeLastBytes = 0;
    final stopwatch = Stopwatch()..start();

    // 下载视频轨
    await _downloadPart(videoPath, videoUrl, job, (received, total) {
      videoTotal = total;
      final cumulativeTotal = total + audioTotal;
      final cumulativeReceived = received + audioTotal;
      _updateProgress(job, cumulativeReceived, cumulativeTotal,
          cumulativeLastBytes, stopwatch);
      cumulativeLastBytes = cumulativeReceived;
    });

    // 下载音频轨
    await _downloadPart(audioPath, audioUrl, job, (received, total) {
      audioTotal = total;
      final cumulativeTotal = videoTotal + total;
      final cumulativeReceived = videoTotal + received;
      _updateProgress(job, cumulativeReceived, cumulativeTotal,
          cumulativeLastBytes, stopwatch);
      cumulativeLastBytes = cumulativeReceived;
    });

    job.filePath = videoPath;
  }

  /// 下载单文件格式
  Future<void> _downloadSingleFile(
    DownloadJob job,
    String url,
    Directory downloadDir,
  ) async {
    final videoPath =
        '${downloadDir.path}/${_safeFileName(job.episodeName)}.mp4';
    int lastBytes = 0;
    final stopwatch = Stopwatch()..start();
    await _downloadPart(videoPath, url, job, (received, total) {
      _updateProgress(job, received, total, lastBytes, stopwatch);
      lastBytes = received;
    });
    job.filePath = videoPath;
  }

  /// 更新下载进度（支持 DASH 合并进度）
  void _updateProgress(DownloadJob job, int received, int total,
      int lastBytes, Stopwatch stopwatch) {
    job.downloadedBytes = received;
    job.totalBytes = total;
    if (total > 0) {
      job.progress = (received * 100 / total).round();
    }
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed >= 1000) {
      final bytesDiff = received - lastBytes;
      job.speed = bytesDiff / (elapsed / 1000);
      stopwatch.reset();
    }
    _jobController.add(job);
  }

  /// 下载单个文件，通过回调报告进度
  Future<void> _downloadPart(
    String path,
    String url,
    DownloadJob job,
    void Function(int received, int total) onProgress,
  ) async {
    final dio = Dio();
    final cancelToken = CancelToken();
    _cancelTokens[job.id] = cancelToken;

    try {
      await dio.download(
        url,
        path,
        options: Options(
          headers: {
            'User-Agent': AppConstants.userAgent,
            'Referer': 'https://www.bilibili.com/',
          },
        ),
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (job.status == DownloadStatus.canceled) {
            cancelToken.cancel();
            return;
          }
          onProgress(received, total);
        },
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      rethrow;
    } finally {
      _cancelTokens.remove(job.id);
    }
  }

  /// 处理下载错误，支持自动重试
  Future<void> _handleDownloadError(DownloadJob job, dynamic error) async {
    LogService.error('下载失败: ${job.videoName}', error);
    if (job.retryCount < AppConstants.maxRetries) {
      job.retryCount++;
      job.status = DownloadStatus.queued;
      job.error = null;
      _jobController.add(job);
      _processQueue();
      return;
    }
    job.status = DownloadStatus.failed;
    job.error = error.toString();
    job.finishedAt = DateTime.now();
  }

  /// 取消任务
  void cancel(String jobId) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) return;
    final job = _jobs[index];
    if (job.status == DownloadStatus.queued ||
        job.status == DownloadStatus.downloading) {
      job.status = DownloadStatus.canceled;
      job.finishedAt = DateTime.now();
      _cancelTokens[jobId]?.cancel();
      _cancelTokens.remove(jobId);
      _jobController.add(job);
    }
  }

  /// 重试任务
  void retry(String jobId) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) return;
    final job = _jobs[index];
    if (job.status == DownloadStatus.failed ||
        job.status == DownloadStatus.canceled) {
      job.status = DownloadStatus.queued;
      job.error = null;
      job.progress = 0;
      job.downloadedBytes = 0;
      job.totalBytes = 0;
      job.startedAt = null;
      job.finishedAt = null;
      _jobController.add(job);
      _processQueue();
    }
  }

  /// 删除任务
  void remove(String jobId) {
    _jobs.removeWhere((j) => j.id == jobId);
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
