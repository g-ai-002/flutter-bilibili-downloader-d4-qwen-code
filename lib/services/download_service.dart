import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/download_job.dart';
import '../utils/constants.dart';
import 'bilibili_api.dart';
import 'file_system_service.dart';
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

  /// 恢复持久化的下载任务（app 重启后调用）
  void restoreJobs(List<DownloadJob> savedJobs) {
    for (final savedJob in savedJobs) {
      // 只恢复尚未完成的任务
      if (savedJob.status == DownloadStatus.queued ||
          savedJob.status == DownloadStatus.downloading) {
        // 重置为排队状态
        savedJob.status = DownloadStatus.queued;
        savedJob.error = null;
        // 确保 id 不冲突
        final idNum = int.tryParse(savedJob.id.split('_').first) ?? 0;
        if (idNum >= _nextId) {
          _nextId = idNum + 1;
        }
        _jobs.add(savedJob);
        _jobController.add(savedJob);
      } else if (savedJob.status == DownloadStatus.completed ||
          savedJob.status == DownloadStatus.failed ||
          savedJob.status == DownloadStatus.canceled) {
        // 已完成/失败/取消的任务直接加入列表（不重新下载）
        _jobs.add(savedJob);
      }
    }
    _processQueue();
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
      // getPlayUrl 失败时会抛出 BilibiliApiException，错误消息已是面向用户的可读文案
      final playUrl = await _api.getPlayUrl(
        job.bvid,
        job.cid,
        int.tryParse(job.formatId) ?? 80,
      );

      if (playUrl == null) {
        throw Exception('无法获取播放地址：服务端返回空地址，请稍后重试');
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
      final root = await FileSystemService.instance.getDownloadRoot();
      final downloadDir = Directory(
          '${root.path}${Platform.pathSeparator}${_safeFileName(job.videoName)}');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final isDASH = audioUrl != null && audioUrl.isNotEmpty;

      if (isDASH) {
        await _downloadDASH(job, videoUrl, audioUrl!, downloadDir);
      } else {
        await _downloadSingleFile(job, videoUrl, downloadDir);
      }

      // 下载过程中任务可能已被删除，检查是否仍存在
      if (!_jobs.any((j) => j.id == job.id)) {
        _activeCount--;
        _processQueue();
        return;
      }

      job.status = DownloadStatus.completed;
      job.progress = 100;
      job.finishedAt = DateTime.now();
      NotificationService.instance
          .showDownloadComplete(job.videoName, job.episodeName);
    } catch (e) {
      await _handleDownloadError(job, e);
    }

    // 下载过程中任务可能已被删除，检查是否仍存在
    if (!_jobs.any((j) => j.id == job.id)) {
      _activeCount--;
      _processQueue();
      return;
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
    final sep = Platform.pathSeparator;
    final base = '${downloadDir.path}$sep${_safeFileName(job.episodeName)}';
    final videoPath = '${base}_video.mp4';
    final audioPath = '${base}_audio.m4a';
    final mergedPath = '$base.mp4';

    int videoTotal = 0;
    int audioTotal = 0;

    // 速度计算用：每个 part 独立跟踪上次测量的字节数和时间
    int partLastBytes = 0;
    DateTime partLastTime = DateTime.now();

    void onPartProgress(int partReceived, int partTotal, int cumulativeReceived, int cumulativeTotal) {
      // 总进度基于累计值（DASH 两个文件合并计算）
      job.downloadedBytes = cumulativeReceived;
      job.totalBytes = cumulativeTotal;
      if (cumulativeTotal > 0) {
        job.progress = (cumulativeReceived * 100 / cumulativeTotal).round().clamp(0, 99);
      }
      // 速度基于 part 增量（避免跨 part 的累积值干扰）
      final now = DateTime.now();
      final timeDiffMs = now.difference(partLastTime).inMilliseconds;
      if (timeDiffMs >= 1000 && partReceived > partLastBytes) {
        final bytesDiff = partReceived - partLastBytes;
        if (bytesDiff > 0) {
          job.speed = bytesDiff / (timeDiffMs / 1000.0);
        }
        partLastBytes = partReceived;
        partLastTime = now;
      }
      _jobController.add(job);
    }

    // 下载视频轨
    await _downloadPart(videoPath, videoUrl, job, (received, total) {
      videoTotal = total > 0 ? total : videoTotal;
      final cumulativeTotal = calcCumulativeTotal(total, audioTotal);
      final cumulativeReceived = received + (audioTotal > 0 ? audioTotal : 0);
      onPartProgress(received, total, cumulativeReceived, cumulativeTotal);
    });

    // 视频轨完成后检查是否已被删除
    if (!_jobs.any((j) => j.id == job.id)) return;

    // 重置 part 速度追踪，避免视频轨残余值干扰音频轨速度
    partLastBytes = 0;
    partLastTime = DateTime.now();

    // 下载音频轨
    await _downloadPart(audioPath, audioUrl, job, (received, total) {
      audioTotal = total > 0 ? total : audioTotal;
      final cumulativeTotal = calcCumulativeTotal(videoTotal, total);
      final cumulativeReceived = (videoTotal > 0 ? videoTotal : 0) + received;
      onPartProgress(received, total, cumulativeReceived, cumulativeTotal);
    });

    // 两段都下载完成，标记 99%（合并阶段）
    job.progress = 99;
    job.mergeStartedAt = DateTime.now();
    _jobController.add(job);

    // 尝试合并视频/音频（Android: Media3 Transformer; 桌面: ffmpeg）
    final merged = await FileSystemService.instance.mergeAv(
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: mergedPath,
    );
    job.mergeFinishedAt = DateTime.now();
    if (merged != null) {
      job.filePath = merged;
      job.audioPath = null;
      LogService.info('已合并视频/音频: $merged');
    } else {
      // 未合并：filePath 指向视频文件，audioPath 指向音频文件
      job.filePath = videoPath;
      job.audioPath = audioPath;
    }
  }

  /// 计算 DASH 累计总大小（处理 total=-1 的未知大小情况）
  static int calcCumulativeTotal(int part1Total, int part2Total) {
    if (part1Total > 0 && part2Total > 0) return part1Total + part2Total;
    if (part1Total > 0) return part1Total;
    if (part2Total > 0) return part2Total;
    return 0;
  }

  /// 下载单文件格式
  Future<void> _downloadSingleFile(
    DownloadJob job,
    String url,
    Directory downloadDir,
  ) async {
    final videoPath =
        '${downloadDir.path}${Platform.pathSeparator}${_safeFileName(job.episodeName)}.mp4';
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    await _downloadPart(videoPath, url, job, (received, total) {
      job.downloadedBytes = received;
      job.totalBytes = total;
      if (total > 0) {
        job.progress = (received * 100 / total).round().clamp(0, 99);
      }
      // 速度基于增量计算
      final now = DateTime.now();
      final timeDiffMs = now.difference(lastTime).inMilliseconds;
      if (timeDiffMs >= 1000 && received > lastBytes) {
        final bytesDiff = received - lastBytes;
        if (bytesDiff > 0) {
          job.speed = bytesDiff / (timeDiffMs / 1000.0);
        }
        lastBytes = received;
        lastTime = now;
      }
      _jobController.add(job);
    });
    job.filePath = videoPath;
  }

  /// 下载单个文件，通过回调报告进度（支持断点续传）
  Future<void> _downloadPart(
    String path,
    String url,
    DownloadJob job,
    void Function(int received, int total) onProgress,
  ) async {
    final dio = Dio();
    final cancelToken = CancelToken();
    _cancelTokens[job.id] = cancelToken;

    final file = File(path);
    int startByte = 0;
    if (await file.exists()) {
      startByte = await file.length();
    }

    try {
      if (startByte > 0) {
        // 断点续传：使用 HTTP Range 请求从已有字节处继续下载
        LogService.info('断点续传: $path, 已下载 $startByte 字节');
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': AppConstants.userAgent,
              'Referer': 'https://www.bilibili.com/',
              'Range': 'bytes=$startByte-',
            },
            responseType: ResponseType.stream,
          ),
          cancelToken: cancelToken,
        );

        // 解析 Content-Range 获取总大小
        int totalSize = 0;
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          final match = RegExp(r'/(\d+)').firstMatch(contentRange);
          if (match != null) {
            totalSize = int.tryParse(match.group(1)!) ?? 0;
          }
        }
        // 如果服务端返回 200（无 Range 支持），则总大小为 Content-Length
        if (totalSize == 0) {
          final contentLength =
              response.headers.value('content-length');
          if (contentLength != null) {
            totalSize = startByte + (int.tryParse(contentLength) ?? 0);
          }
        }

        final raf = await file.open(mode: FileMode.append);
        try {
          int received = startByte;
          await for (final chunk in response.data.stream) {
            if (job.status == DownloadStatus.canceled) {
              cancelToken.cancel();
              return;
            }
            await raf.writeFrom(chunk);
            received += chunk.length;
            onProgress(received, totalSize);
          }
        } finally {
          await raf.close();
        }
      } else {
        // 全新下载
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
      }
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
  /// 业务类错误（未登录/会员限制/风控）不重试，避免无效重复刷接口。
  Future<void> _handleDownloadError(DownloadJob job, dynamic error) async {
    LogService.error('下载失败: ${job.videoName}', error);
    final isBusinessError = error is BilibiliApiException;
    if (!isBusinessError && job.retryCount < AppConstants.maxRetries) {
      job.retryCount++;
      job.status = DownloadStatus.queued;
      job.error = null;
      _jobController.add(job);
      _processQueue();
      return;
    }
    job.status = DownloadStatus.failed;
    job.error = error is BilibiliApiException ? error.message : error.toString();
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

  /// 删除任务（下载中则先取消）
  void remove(String jobId) {
    // 如果正在下载，先取消
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx >= 0) {
      final job = _jobs[idx];
      if (job.status == DownloadStatus.downloading ||
          job.status == DownloadStatus.queued) {
        _cancelTokens[jobId]?.cancel();
        _cancelTokens.remove(jobId);
      }
    }
    _jobs.removeWhere((j) => j.id == jobId);
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
