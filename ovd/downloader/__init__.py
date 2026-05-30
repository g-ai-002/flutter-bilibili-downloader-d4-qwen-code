"""下载器子包: ffmpeg 调用 + 异步任务队列。"""
try:
    from ovd.downloader.jobs import BILIBILI_DEFAULT_FORMAT, DownloadJob, JobManager, JobStatus
except ImportError:
    from .jobs import BILIBILI_DEFAULT_FORMAT, DownloadJob, JobManager, JobStatus

__all__ = ["BILIBILI_DEFAULT_FORMAT", "DownloadJob", "JobManager", "JobStatus"]
