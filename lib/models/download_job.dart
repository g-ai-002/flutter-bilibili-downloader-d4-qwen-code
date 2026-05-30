/// 下载任务数据模型

enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled;

  String get label {
    switch (this) {
      case DownloadStatus.queued:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败';
      case DownloadStatus.canceled:
        return '已取消';
    }
  }
}

class DownloadJob {
  final String id;
  final String videoName;
  final String episodeName;
  final String bvid;
  final int cid;
  final String formatId;
  final String quality;
  DownloadStatus status;
  String? error;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? finishedAt;
  int progress; // 0-100
  int downloadedBytes;
  int totalBytes;
  double speed; // bytes/sec
  String? filePath;
  int retryCount;

  DownloadJob({
    required this.id,
    required this.videoName,
    required this.episodeName,
    required this.bvid,
    required this.cid,
    required this.formatId,
    required this.quality,
    this.status = DownloadStatus.queued,
    this.error,
    DateTime? createdAt,
    this.startedAt,
    this.finishedAt,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speed = 0,
    this.filePath,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoName': videoName,
        'episodeName': episodeName,
        'bvid': bvid,
        'cid': cid,
        'formatId': formatId,
        'quality': quality,
        'status': status.name,
        'error': error,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'speed': speed,
        'filePath': filePath,
        'retryCount': retryCount,
      };

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    return DownloadJob(
      id: json['id'] as String,
      videoName: json['videoName'] as String? ?? '',
      episodeName: json['episodeName'] as String? ?? '',
      bvid: json['bvid'] as String? ?? '',
      cid: json['cid'] as int? ?? 0,
      formatId: json['formatId'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DownloadStatus.queued,
      ),
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      progress: json['progress'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      filePath: json['filePath'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  String get duration {
    if (startedAt == null) return '';
    final end = finishedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    if (diff.inHours > 0) {
      return '${diff.inHours}:${diff.inMinutes.remainder(60).toString().padLeft(2, '0')}:${diff.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${diff.inMinutes}:${diff.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  String get speedText {
    if (speed <= 0) return '';
    if (speed >= 1024 * 1024) {
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    return '${(speed / 1024).toStringAsFixed(1)} KB/s';
  }
}
