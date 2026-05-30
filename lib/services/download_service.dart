import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_job.dart';
import '../utils/constants.dart';
import 'bilibili_api.dart';
import 'log_service.dart';

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
      final pending = _jobs.where((j) => j.status == DownloadStatus.queued).toList();
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
      // 获取播放 URL
      final playUrl = await _api.getPlayUrl(
        job.bvid,
        int.tryParse(job.formatId) ?? 80,
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
      final downloadDir = Directory('${dir.path}/downloads/${_safeFileName(job.videoName)}');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 下载视频
      final videoPath = '${downloadDir.path}/${_safeFileName(job.episodeName)}_video.mp4';
      await _downloadFile(videoUrl, videoPath, job);

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final audioPath = '${downloadDir.path}/${_safeFileName(job.episodeName)}_audio.m4a';
        await _downloadFile(audioUrl, audioPath, job);
      }

      job.filePath = '${downloadDir.path}/${_safeFileName(job.episodeName)}.mp4';
      job.status = DownloadStatus.completed;
      job.progress = 100;
      job.finishedAt = DateTime.now();
    } catch (e) {
      LogService.error('下载失败: ${job.videoName}', e);
      if (job.retryCount < AppConstants.maxRetries) {
        job.retryCount++;
        job.status = DownloadStatus.queued;
        job.error = null;
        _jobController.add(job);
        _processQueue();
        return;
      }
      job.status = DownloadStatus.failed;
      job.error = e.toString();
      job.finishedAt = DateTime.now();
    }

    _activeCount--;
    _jobController.add(job);
    _processQueue();
  }

  /// 下载单个文件
  Future<void> _downloadFile(String url, String path, DownloadJob job) async {
    final dio = Dio();
    CancelToken cancelToken = CancelToken();
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
          job.downloadedBytes = received;
          job.totalBytes = total;
          if (total > 0) {
            job.progress = (received * 100 / total).round();
          }
          _jobController.add(job);
        },
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // 取消操作，不视为错误
        return;
      }
      rethrow;
    } finally {
      _cancelTokens.remove(job.id);
    }
  }

  /// 取消任务
  void cancel(String jobId) {
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index < 0) return;
    final job = _jobs[index];
    if (job.status == DownloadStatus.queued || job.status == DownloadStatus.downloading) {
      job.status = DownloadStatus.canceled;
      job.finishedAt = DateTime.now();
      // 取消正在进行的网络请求
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
    if (job.status == DownloadStatus.failed || job.status == DownloadStatus.canceled) {
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
