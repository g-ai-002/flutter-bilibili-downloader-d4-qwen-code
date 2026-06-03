/// 视频文件元数据（分辨率、帧率、编码等信息）
class VideoMetadata {
  final int? width;
  final int? height;
  final double? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? fileSize;
  final int? durationSeconds;

  const VideoMetadata({
    this.width,
    this.height,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.fileSize,
    this.durationSeconds,
  });
}
