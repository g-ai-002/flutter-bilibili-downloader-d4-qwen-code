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
  DateTime? mergeStartedAt;
  DateTime? mergeFinishedAt;
  int progress; // 0-100
  int downloadedBytes;
  int totalBytes;
  double speed; // bytes/sec
  String? filePath;
  String? audioPath; // DASH 未合并时的音频文件路径
  int retryCount;
  // 视频元数据
  String? pic; // 封面 URL
  int? fileSize; // 文件大小（字节）
  int? videoWidth;
  int? videoHeight;
  double? fps;
  String? videoCodec;
  String? audioCodec;

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
    this.mergeStartedAt,
    this.mergeFinishedAt,
    this.progress = 0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speed = 0,
    this.filePath,
    this.audioPath,
    this.retryCount = 0,
    this.pic,
    this.fileSize,
    this.videoWidth,
    this.videoHeight,
    this.fps,
    this.videoCodec,
    this.audioCodec,
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
        'mergeStartedAt': mergeStartedAt?.toIso8601String(),
        'mergeFinishedAt': mergeFinishedAt?.toIso8601String(),
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'speed': speed,
        'filePath': filePath,
        'audioPath': audioPath,
        'retryCount': retryCount,
        'pic': pic,
        'fileSize': fileSize,
        'videoWidth': videoWidth,
        'videoHeight': videoHeight,
        'fps': fps,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
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
      mergeStartedAt: json['mergeStartedAt'] != null
          ? DateTime.parse(json['mergeStartedAt'] as String)
          : null,
      mergeFinishedAt: json['mergeFinishedAt'] != null
          ? DateTime.parse(json['mergeFinishedAt'] as String)
          : null,
      progress: json['progress'] as int? ?? 0,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      filePath: json['filePath'] as String?,
      audioPath: json['audioPath'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      pic: json['pic'] as String?,
      fileSize: json['fileSize'] as int?,
      videoWidth: json['videoWidth'] as int?,
      videoHeight: json['videoHeight'] as int?,
      fps: (json['fps'] as num?)?.toDouble(),
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String?,
    );
  }

  String get duration {
    if (startedAt == null) return '';
    final end = finishedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    return _formatDuration(diff);
  }

  /// 下载阶段用时（排除合并时间）
  String get downloadDuration {
    if (startedAt == null) return '';
    final end = mergeStartedAt ?? finishedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    return _formatDuration(diff);
  }

  /// 合并阶段用时
  String get mergeDuration {
    if (mergeStartedAt == null) return '';
    final end = mergeFinishedAt ?? DateTime.now();
    final diff = end.difference(mergeStartedAt!);
    return _formatDuration(diff);
  }

  /// 总用时（含下载+合并）
  String get totalDuration {
    if (startedAt == null) return '';
    final end = finishedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    return _formatDuration(diff);
  }

  /// 预估剩余时间
  String get remainingTime {
    if (speed <= 0 || totalBytes <= 0) return '';
    final remainingBytes = totalBytes - downloadedBytes;
    if (remainingBytes <= 0) return '';
    final seconds = remainingBytes / speed;
    if (seconds > 3600) {
      return '剩余 ${(seconds / 3600).toStringAsFixed(1)} 小时';
    } else if (seconds > 60) {
      return '剩余 ${(seconds / 60).toStringAsFixed(0)} 分钟';
    }
    return '剩余 ${seconds.toStringAsFixed(0)} 秒';
  }

  /// 已执行时间
  String get elapsedTime {
    if (startedAt == null) return '';
    final end = finishedAt ?? DateTime.now();
    final diff = end.difference(startedAt!);
    return _formatDuration(diff);
  }

  String _formatDuration(Duration diff) {
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
