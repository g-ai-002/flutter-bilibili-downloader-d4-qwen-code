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
  DateTime _lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _notifyThrottle = Duration(milliseconds: 200);
  DateTime _lastPersistTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _persistThrottle = Duration(seconds: 2);

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

    // 立即注册 stream 监听，避免异步加载期间 addJob 丢失
    service.jobStream.listen((job) {
      final index = _jobs.indexWhere((j) => j.id == job.id);
      if (index >= 0) {
        _jobs[index] = job;
      } else {
        _jobs.insert(0, job);
      }
      _throttledNotify(job);
      _throttledPersist(job);
    });

    // 加载持久化的下载任务
    try {
      final storage = await StorageService.instance;
      final persisted = await storage.loadDownloadJobs();
      if (persisted.isNotEmpty) {
        // 恢复任务到下载服务（含续传排队任务，会触发 stream 事件）
        service.restoreJobs(persisted);
        // 同步未通过 stream 发出的任务（已完成/失败/取消）
        _jobs = List<DownloadJob>.from(service.jobs);
        notifyListeners();
      }
    } catch (e) {
      LogService.error('加载下载历史失败', e);
    }

    _initialized = true;
  }

  /// 持久化保存下载任务（捕获当前列表快照，避免并发读写竞态）
  Future<void> _persistJobs() async {
    final snapshot = List<DownloadJob>.from(_jobs);
    try {
      final storage = await StorageService.instance;
      await storage.saveDownloadJobs(snapshot);
    } catch (e) {
      LogService.error('保存下载历史失败', e);
    }
  }

  /// 节流持久化：状态变化（非 downloading）立即保存；下载进度中最多每 2 秒保存一次
  void _throttledPersist(DownloadJob job) {
    final now = DateTime.now();
    if (job.status != DownloadStatus.downloading ||
        now.difference(_lastPersistTime) >= _persistThrottle) {
      _lastPersistTime = now;
      _persistJobs();
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
    String? pic,
    int? durationSeconds,
  }) {
    _service?.addJob(
      videoName: videoName,
      episodeName: episodeName,
      bvid: bvid,
      cid: cid,
      formatId: formatId,
      quality: quality,
      pic: pic,
      durationSeconds: durationSeconds,
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
    _jobs = List<DownloadJob>.from(_jobs)..removeWhere((j) => j.id == jobId);
    notifyListeners();
    _persistJobs();
  }

  /// 清除已完成任务
  void clearCompleted() {
    final toRemove = _jobs.where((j) => j.status == DownloadStatus.completed).toList();
    for (final job in toRemove) {
      _service?.remove(job.id);
    }
    _jobs = List<DownloadJob>.from(_jobs)..removeWhere((j) => j.status == DownloadStatus.completed);
    notifyListeners();
    _persistJobs();
  }

  /// 清除失败任务
  void clearFailed() {
    final toRemove = _jobs.where((j) => j.status == DownloadStatus.failed).toList();
    for (final job in toRemove) {
      _service?.remove(job.id);
    }
    _jobs = List<DownloadJob>.from(_jobs)..removeWhere((j) => j.status == DownloadStatus.failed);
    notifyListeners();
    _persistJobs();
  }

  /// 清除已取消任务
  void clearCanceled() {
    final toRemove = _jobs.where((j) => j.status == DownloadStatus.canceled).toList();
    for (final job in toRemove) {
      _service?.remove(job.id);
    }
    _jobs = List<DownloadJob>.from(_jobs)..removeWhere((j) => j.status == DownloadStatus.canceled);
    notifyListeners();
    _persistJobs();
  }

  /// 清除排队中任务
  void clearQueued() {
    final toRemove = _jobs.where((j) => j.status == DownloadStatus.queued).toList();
    for (final job in toRemove) {
      _service?.cancel(job.id);
      _service?.remove(job.id);
    }
    _jobs = List<DownloadJob>.from(_jobs)..removeWhere((j) => j.status == DownloadStatus.queued);
    notifyListeners();
    _persistJobs();
  }

  /// 重试所有失败任务
  void retryAll() {
    for (final job in _jobs) {
      if (job.status == DownloadStatus.failed) {
        _service?.retry(job.id);
      }
    }
  }

  /// 节流通知：状态变更立即通知，进度更新限制频率避免窗口拖动时卡顿
  void _throttledNotify(DownloadJob job) {
    final now = DateTime.now();
    // 状态变化（非 downloading）或距上次通知超过节流间隔才触发
    if (job.status != DownloadStatus.downloading ||
        now.difference(_lastNotifyTime) >= _notifyThrottle) {
      _lastNotifyTime = now;
      notifyListeners();
    }
  }
}
