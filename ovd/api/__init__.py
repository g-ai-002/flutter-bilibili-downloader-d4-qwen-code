"""ovd.api 子包: 第三方数据源访问。"""
try:
    from ovd.api.maccms import (
        Episode,
        MacCMSClient,
        PlaySource,
        VideoDetail,
        VideoSummary,
    )
    from ovd.api.bilibili import (
        BiliBiliClient,
        BiliEpisode,
        BiliSearchResult,
        BiliUploaderResult,
        BiliUploaderVideo,
        BiliVideoDetail,
        BiliVideoFormat,
    )
except ImportError:
    from .maccms import (
        Episode,
        MacCMSClient,
        PlaySource,
        VideoDetail,
        VideoSummary,
    )
    from .bilibili import (
        BiliBiliClient,
        BiliEpisode,
        BiliSearchResult,
        BiliUploaderResult,
        BiliUploaderVideo,
        BiliVideoDetail,
        BiliVideoFormat,
    )

__all__ = [
    "Episode",
    "MacCMSClient",
    "PlaySource",
    "VideoDetail",
    "VideoSummary",
    "BiliBiliClient",
    "BiliEpisode",
    "BiliSearchResult",
    "BiliUploaderResult",
    "BiliUploaderVideo",
    "BiliVideoDetail",
    "BiliVideoFormat",
]
