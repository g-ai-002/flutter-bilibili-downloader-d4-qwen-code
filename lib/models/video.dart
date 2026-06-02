/// Bilibili 视频数据模型

class BiliVideo {
  final String bvid;
  final String title;
  final String pic;
  final String uploader;
  final String duration;
  final String viewCount;
  final String pubdate;

  BiliVideo({
    required this.bvid,
    required this.title,
    required this.pic,
    required this.uploader,
    required this.duration,
    required this.viewCount,
    required this.pubdate,
  });

  factory BiliVideo.fromJson(Map<String, dynamic> json) {
    return BiliVideo(
      bvid: json['bvid'] as String? ?? '',
      title: json['title'] as String? ?? '',
      pic: json['pic'] as String? ?? '',
      uploader: json['uploader'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      viewCount: json['view_count'] as String? ?? '',
      pubdate: json['pubdate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'bvid': bvid,
        'title': title,
        'pic': pic,
        'uploader': uploader,
        'duration': duration,
        'view_count': viewCount,
        'pubdate': pubdate,
      };
}

class BiliVideoDetail {
  final String bvid;
  final String title;
  final String pic;
  final String desc;
  final String uploader;
  final int uploaderMid;
  final String uploaderFace;
  final int duration;
  final List<BiliEpisode> episodes;
  final List<BiliVideoFormat> formats;
  final int pubdate; // Unix 时间戳
  final int viewCount; // 播放量

  BiliVideoDetail({
    required this.bvid,
    required this.title,
    required this.pic,
    required this.desc,
    required this.uploader,
    this.uploaderMid = 0,
    this.uploaderFace = '',
    required this.duration,
    required this.episodes,
    required this.formats,
    this.pubdate = 0,
    this.viewCount = 0,
  });
}

class BiliEpisode {
  final int page;
  final String name;
  final int? cid;
  final String bvid;
  final String url;

  BiliEpisode({
    required this.page,
    required this.name,
    this.cid,
    required this.bvid,
    required this.url,
  });
}

class BiliVideoFormat {
  final String formatId;
  final String ext;
  final String quality;
  final int? width;
  final int? height;
  final bool hasVideo;
  final bool hasAudio;

  const BiliVideoFormat({
    required this.formatId,
    required this.ext,
    required this.quality,
    this.width,
    this.height,
    required this.hasVideo,
    required this.hasAudio,
  });
}

class BiliUploader {
  final int mid;
  final String name;
  final String face;
  final String fans;
  final String sign;

  BiliUploader({
    required this.mid,
    required this.name,
    required this.face,
    required this.fans,
    required this.sign,
  });
}

/// 当前登录用户信息
class BiliUserInfo {
  final int mid;
  final String uname;
  final String face;
  final int level;

  BiliUserInfo({
    required this.mid,
    required this.uname,
    required this.face,
    this.level = 0,
  });
}
