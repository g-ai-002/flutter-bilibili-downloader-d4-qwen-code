"""单元测试: 文件名 / 任务管理。"""

from pathlib import Path

import yt_dlp
import pytest

from ovd.config import Settings
from ovd.downloader.jobs import JobManager, JobStatus, safe_filename


def test_safe_filename_strips_bad_chars():
    assert safe_filename('遮天/第01集') == '遮天_第01集'
    assert safe_filename('a:b*c?d"e<f>g|h') == 'a_b_c_d_e_f_g_h'
    assert safe_filename('   ') == 'untitled'


def test_safe_filename_limits_component_length():
    assert len(safe_filename('遮' * 200).encode('utf-8')) <= 240
    assert len(safe_filename('a' * 300).encode('utf-8')) <= 240
    assert len(safe_filename('a' * 300).encode('utf-8')) > 120


def test_enqueue_limits_folder_and_output_filename_lengths(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='超长剧名' * 80,
        episode_name='超长分集名' * 80,
        url='https://example.com/x.m3u8',
    )

    assert len(job.output_path.parent.name.encode('utf-8')) <= 240
    assert len(job.output_path.name.encode('utf-8')) <= 220
    assert len(f'{job.output_path.name}.f137.mp4.part'.encode('utf-8')) <= 255
    assert job.output_path.suffix == '.mp4'


@pytest.mark.asyncio
async def test_enqueue_and_cancel(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='测试剧',
        episode_name='第01集',
        url='https://example.com/x.m3u8',
    )
    assert job.id == 1
    assert job.status == JobStatus.QUEUED
    assert job.output_path.parent == tmp_path / '测试剧'
    assert job.output_path.name == '测试剧-第01集.mp4'
    assert mgr.cancel(job.id) is True
    assert mgr.get(job.id).status == JobStatus.CANCELED


def test_enqueue_uses_video_name_when_episode_name_matches(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='测试视频',
        episode_name='测试视频',
        url='https://example.com/x.m3u8',
    )
    assert job.output_path.parent == tmp_path / '测试视频'
    assert job.output_path.name == '测试视频.mp4'


def test_enqueue_supports_custom_folder_name(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)

    job = mgr.enqueue(
        video_name='投稿标题',
        episode_name='投稿标题',
        url='https://www.bilibili.com/video/BV1xx411c7mD?format=bestvideo[height<=1080]+bestaudio/best[height<=1080]/best',
        folder_name='黑鹤001',
    )

    assert job.output_path.parent == tmp_path / '黑鹤001'
    assert job.output_path.name == '投稿标题.mp4'


def test_retry_failed_job_requeues_and_resets_state(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    job.status = JobStatus.FAILED
    job.error = "RuntimeError('broken')"
    job.retry_count = 3
    job.total_chunks = 100
    job.downloaded_chunks = 50
    job.bytes_downloaded = 1024
    job.download_speed = 2048
    job.started_at = 1.0
    job.finished_at = 2.0

    assert mgr.retry(job.id) is True

    assert job.status == JobStatus.QUEUED
    assert job.error is None
    assert job.retry_count == 0
    assert job.total_chunks == 0
    assert job.downloaded_chunks == 0
    assert job.bytes_downloaded == 0
    assert job.download_speed == 0.0
    assert job.started_at is None
    assert job.finished_at is None


def test_retry_canceled_job_requeues(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    assert mgr.cancel(job.id) is True

    assert mgr.retry(job.id) is True

    assert job.status == JobStatus.QUEUED
    assert job.finished_at is None


def test_retry_removes_bilibili_fragment_files(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="测试视频",
        url="https://www.bilibili.com/video/BV1xx411c7mD?format=bestvideo[height<=1080]+bestaudio/best[height<=1080]/best",
        folder_name="黑鹤001",
    )
    job.status = JobStatus.FAILED
    video_fragment = job.output_path.with_name(f"{job.output_path.stem}.f100026.mp4")
    audio_fragment = job.output_path.with_name(f"{job.output_path.stem}.f30280.m4a")
    unrelated_file = job.output_path.with_name(f"{job.output_path.stem}.cover.jpg")
    video_fragment.write_bytes(b"bad video fragment")
    audio_fragment.write_bytes(b"audio fragment")
    unrelated_file.write_bytes(b"keep")

    assert mgr.retry(job.id) is True

    assert not video_fragment.exists()
    assert not audio_fragment.exists()
    assert unrelated_file.exists()


def test_retry_rejects_completed_and_downloading_jobs(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    completed = mgr.enqueue(
        video_name="完成视频",
        episode_name="第01集",
        url="https://example.com/completed.m3u8",
    )
    completed.status = JobStatus.COMPLETED
    downloading = mgr.enqueue(
        video_name="下载中视频",
        episode_name="第01集",
        url="https://example.com/downloading.m3u8",
    )
    downloading.status = JobStatus.DOWNLOADING

    assert mgr.retry(completed.id) is False
    assert mgr.retry(downloading.id) is False
    assert mgr.retry(999) is False


def test_delete_job_file_removes_empty_parent_directory(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='投稿标题',
        episode_name='投稿标题',
        url='https://example.com/x.m3u8',
        folder_name='黑鹤001',
    )
    job.output_path.write_text('video')

    assert mgr.delete_job_file(job.id) is True

    assert not job.output_path.exists()
    assert not (tmp_path / '黑鹤001').exists()


def test_delete_job_file_keeps_non_empty_parent_directory(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    first = mgr.enqueue(
        video_name='投稿1',
        episode_name='投稿1',
        url='https://example.com/1.m3u8',
        folder_name='黑鹤001',
    )
    second = mgr.enqueue(
        video_name='投稿2',
        episode_name='投稿2',
        url='https://example.com/2.m3u8',
        folder_name='黑鹤001',
    )
    first.output_path.write_text('video1')
    second.output_path.write_text('video2')

    assert mgr.delete_job_file(first.id) is True

    assert not first.output_path.exists()
    assert (tmp_path / '黑鹤001').exists()


@pytest.mark.asyncio
async def test_existing_completed_job_size_matches_output_file(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='测试视频',
        episode_name='第01集',
        url='https://example.com/x.m3u8',
    )
    job.bytes_downloaded = 1
    job.output_path.write_bytes(b'existing-final-video')

    await mgr._run_one(job)

    assert job.status == JobStatus.COMPLETED
    assert job.bytes_downloaded == job.output_path.stat().st_size


@pytest.mark.asyncio
async def test_completed_job_size_matches_output_file(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name='测试视频',
        episode_name='第01集',
        url='https://example.com/x.m3u8',
    )

    async def fake_download(job):
        job.bytes_downloaded = 1
        job.output_path.write_bytes(b'final-video')

    mgr._download_m3u8 = fake_download

    await mgr._run_one(job)

    assert job.status == JobStatus.COMPLETED
    assert job.bytes_downloaded == job.output_path.stat().st_size
    assert job.to_dict()["bytes_downloaded"] == job.output_path.stat().st_size


@pytest.mark.asyncio
async def test_run_one_retries_transient_failure_until_success(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    attempts = 0

    async def flaky_download(job):
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise RuntimeError("temporary network error")
        job.output_path.write_bytes(b"final-video")

    mgr._download_m3u8 = flaky_download

    await mgr._run_one(job)
    assert job.status == JobStatus.QUEUED
    assert job.retry_count == 1
    assert job.error == "RuntimeError('temporary network error')"

    await mgr._run_one(job)
    assert job.status == JobStatus.COMPLETED
    assert job.retry_count == 1
    assert job.error is None
    assert attempts == 2


@pytest.mark.asyncio
async def test_run_one_fails_after_retry_limit(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    job.max_retries = 3

    async def always_fails(job):
        raise RuntimeError("still broken")

    mgr._download_m3u8 = always_fails

    for expected_retry_count in (1, 2, 3):
        await mgr._run_one(job)
        assert job.status == JobStatus.QUEUED
        assert job.retry_count == expected_retry_count

    await mgr._run_one(job)

    assert job.status == JobStatus.FAILED
    assert job.retry_count == 3
    assert job.error == "RuntimeError('still broken')"


@pytest.mark.asyncio
async def test_bilibili_download_converts_cookie_text_to_cookiefile(monkeypatch, tmp_path: Path):
    captured_opts = {}
    captured_urls = []

    class FakeYoutubeDL:
        def __init__(self, opts):
            captured_opts.update(opts)
            captured_opts["cookiefile_text"] = Path(opts["cookiefile"]).read_text()

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def download(self, urls):
            captured_urls.extend(urls)

    monkeypatch.setattr(yt_dlp, "YoutubeDL", FakeYoutubeDL)

    cookie_text = f"SESSDATA={'x' * 300}; bili_jct=test-jct"
    settings = Settings(
        download_dir=tmp_path,
        concurrency=1,
        bilibili_cookies=cookie_text,
    )
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="测试视频",
        url="https://www.bilibili.com/video/BV1xx411c7mD?format=bestvideo[height<=1080]+bestaudio/best[height<=1080]/best",
    )

    await mgr._download_bilibili(job)

    cookiefile_text = captured_opts["cookiefile_text"]
    assert "# Netscape HTTP Cookie File" in cookiefile_text
    assert f".bilibili.com\tTRUE\t/\tFALSE\t0\tSESSDATA\t{'x' * 300}" in cookiefile_text
    assert ".bilibili.com\tTRUE\t/\tFALSE\t0\tbili_jct\ttest-jct" in cookiefile_text
    assert "http_headers" not in captured_opts
    assert captured_opts["format"] == "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
    assert captured_urls == ["https://www.bilibili.com/video/BV1xx411c7mD"]


def test_retry_metadata_persists(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    mgr = JobManager(settings)
    job = mgr.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    job.retry_count = 2
    job.max_retries = 3
    mgr.save_jobs()

    loaded = JobManager(settings)
    loaded.load_jobs()
    loaded_job = loaded.get(job.id)

    assert loaded_job is not None
    assert loaded_job.retry_count == 2
    assert loaded_job.max_retries == 3
    assert loaded_job.to_dict()["retry_count"] == 2
    assert loaded_job.to_dict()["max_retries"] == 3


def test_settings_max_jobs_persists(tmp_path: Path):
    settings = Settings(download_dir=tmp_path, concurrency=1)
    assert settings.max_jobs == 10

    settings.save_max_jobs(25)
    loaded = Settings.load_from_dir(tmp_path)

    assert loaded.max_jobs == 25
