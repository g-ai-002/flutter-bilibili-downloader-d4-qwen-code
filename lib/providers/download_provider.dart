import 'package:flutter/foundation.dart';
import '../models/download_job.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../services/log_service.dart';

/// 下载状态管理
class DownloadProvider extends ChangeNotifier {
  DownloadService? _service;
  List<DownloadJob> _jobs = [];
  bool _initialized = false;

  DownloadService? get service => _service;
  List<DownloadJob> get jobs => _jobs;
  bool get initialized => _initialized;
  List<DownloadJob> get activeJobs =>
      _jobs.where((j) => j.status == DownloadStatus.downloading).toList();
  List<DownloadJob> get completedJobs =>
      _jobs.where((j) => j.status == DownloadStatus.completed).toList();
  List<DownloadJob> get failedJobs =>
      _jobs.where((j) => j.status == DownloadStatus.failed).toList();

  /// 初始化并加载持久化的下载任务
  Future<void> initService(DownloadService service) async {
    _service = service;

    // 加载持久化的下载任务
    try {
      final storage = await StorageService.instance;
      final persisted = await storage.loadDownloadJobs();
      if (persisted.isNotEmpty) {
        // 恢复任务到下载服务（包括续传排队中的任务）
        service.restoreJobs(persisted);
        _jobs = service.jobs;
        notifyListeners();
      }
    } catch (e) {
      LogService.error('加载下载历史失败', e);
    }

    _initialized = true;

    service.jobStream.listen((job) {
      final index = _jobs.indexWhere((j) => j.id == job.id);
      if (index >= 0) {
        _jobs[index] = job;
      } else {
        _jobs.insert(0, job);
      }
      notifyListeners();
      // 持久化保存
      _persistJobs();
    });
  }

  /// 持久化保存下载任务
  Future<void> _persistJobs() async {
    try {
      final storage = await StorageService.instance;
      await storage.saveDownloadJobs(_jobs);
    } catch (e) {
      LogService.error('保存下载历史失败', e);
    }
  }

  /// 添加下载任务
  void addJob({
    required String videoName,
    required String episodeName,
    required String bvid,
    required int cid,
    required String formatId,
    required String quality,
  }) {
    _service?.addJob(
      videoName: videoName,
      episodeName: episodeName,
      bvid: bvid,
      cid: cid,
      formatId: formatId,
      quality: quality,
    );
  }

  /// 取消任务
  void cancel(String jobId) {
    _service?.cancel(jobId);
  }

  /// 重试任务
  void retry(String jobId) {
    _service?.retry(jobId);
  }

  /// 删除任务
  void remove(String jobId) {
    _service?.remove(jobId);
    _jobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
  }

  /// 清除已完成任务
  void clearCompleted() {
    _jobs.removeWhere((j) => j.status == DownloadStatus.completed);
    notifyListeners();
  }

  /// 清除失败任务
  void clearFailed() {
    _jobs.removeWhere((j) => j.status == DownloadStatus.failed);
    notifyListeners();
  }

  /// 清除已取消任务
  void clearCanceled() {
    _jobs.removeWhere((j) => j.status == DownloadStatus.canceled);
    notifyListeners();
  }

  /// 清除排队中任务
  void clearQueued() {
    _jobs.removeWhere((j) => j.status == DownloadStatus.queued);
    notifyListeners();
  }

  /// 重试所有失败任务
  void retryAll() {
    for (final job in _jobs) {
      if (job.status == DownloadStatus.failed) {
        _service?.retry(job.id);
      }
    }
  }
}
