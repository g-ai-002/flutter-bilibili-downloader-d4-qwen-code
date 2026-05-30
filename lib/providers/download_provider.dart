import 'package:flutter/foundation.dart';
import '../models/download_job.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';
import '../services/log_service.dart';

/// 下载状态管理
class DownloadProvider extends ChangeNotifier {
  DownloadService? _service;
  List<DownloadJob> _jobs = [];

  DownloadService? get service => _service;
  List<DownloadJob> get jobs => _jobs;
  List<DownloadJob> get activeJobs =>
      _jobs.where((j) => j.status == DownloadStatus.downloading).toList();
  List<DownloadJob> get completedJobs =>
      _jobs.where((j) => j.status == DownloadStatus.completed).toList();
  List<DownloadJob> get failedJobs =>
      _jobs.where((j) => j.status == DownloadStatus.failed).toList();

  void initService(DownloadService service) {
    _service = service;
    service.jobStream.listen((job) {
      final index = _jobs.indexWhere((j) => j.id == job.id);
      if (index >= 0) {
        _jobs[index] = job;
      } else {
        _jobs.insert(0, job);
      }
      notifyListeners();
    });
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

  /// 重试所有失败任务
  void retryAll() {
    for (final job in _jobs) {
      if (job.status == DownloadStatus.failed) {
        _service?.retry(job.id);
      }
    }
  }
}
