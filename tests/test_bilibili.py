"""单元测试: Bilibili 用户和投稿解析。"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ovd.api import bilibili as bilibili_module
from ovd.api.bilibili import BiliBiliClient, BiliUploaderVideo, _parse_view_video, _parse_uploader_item, _parse_uploader_video
from ovd.config import Settings
from ovd.downloader.jobs import DownloadJob, JobStatus
from ovd.web.app import app


def test_parse_uploader_item_strips_html_and_normalizes_face_url():
    item = {
        "mid": 12345,
        "uname": "<em class=\"keyword\">测试UP</em>",
        "upic": "//i0.hdslb.com/avatar.jpg",
        "fans": 123456,
        "usign": "简介内容",
    }

    uploader = _parse_uploader_item(item)

    assert uploader is not None
    assert uploader.mid == 12345
    assert uploader.name == "测试UP"
    assert uploader.face == "https://i0.hdslb.com/avatar.jpg"
    assert uploader.fans == "12.3万"
    assert uploader.sign == "简介内容"


def test_parse_uploader_video_normalizes_archive_fields():
    item = {
        "bvid": "BV1xx411c7mD",
        "title": "投稿标题",
        "pic": "//i0.hdslb.com/cover.jpg",
        "duration": 95,
        "play": 10001,
        "created": 1710000000,
    }

    video = _parse_uploader_video(item)

    assert video is not None
    assert video.bvid == "BV1xx411c7mD"
    assert video.title == "投稿标题"
    assert video.pic == "https://i0.hdslb.com/cover.jpg"
    assert video.duration == "1:35"
    assert video.view_count == "1.0万"
    assert video.pubdate == "1710000000"


def test_parse_uploader_video_uses_archive_length_text():
    item = {
        "bvid": "BV13P5963Ein",
        "title": "投稿标题",
        "pic": "//i0.hdslb.com/cover.jpg",
        "length": "43:17",
        "play": 39329,
        "created": 1778754415,
    }

    video = _parse_uploader_video(item)

    assert video is not None
    assert video.duration == "43:17"
    assert video.pubdate == "1778754415"


def test_parse_uploader_video_accepts_search_result_duration_text():
    item = {
        "bvid": "BV1xx411c7mD",
        "title": "搜索投稿标题",
        "pic": "//i0.hdslb.com/cover.jpg",
        "duration": "12:34",
        "play": 10001,
        "pubdate": 1710000000,
    }

    video = _parse_uploader_video(item)

    assert video is not None
    assert video.duration == "12:34"
    assert video.view_count == "1.0万"


def test_parse_uploader_video_accepts_search_result_view_count_text():
    item = {
        "bvid": "BV1xx411c7mD",
        "title": "搜索投稿标题",
        "pic": "//i0.hdslb.com/cover.jpg",
        "duration": "12:34",
        "play": "1.2万",
        "pubdate": 1710000000,
    }

    video = _parse_uploader_video(item)

    assert video is not None
    assert video.view_count == "1.2万"


def test_parse_view_video_normalizes_detail_fields():
    item = {
        "bvid": "BV1xx411c7mD",
        "title": "详情标题",
        "pic": "https://i0.hdslb.com/cover.jpg",
        "duration": 125,
        "stat": {"view": 20000},
        "pubdate": 1710000001,
    }

    video = _parse_view_video(item)

    assert video is not None
    assert video.bvid == "BV1xx411c7mD"
    assert video.title == "详情标题"
    assert video.duration == "2:05"
    assert video.view_count == "2.0万"
    assert video.pubdate == "1710000001"


def test_client_exposes_uploader_methods():
    assert hasattr(BiliBiliClient, "search_uploaders")
    assert hasattr(BiliBiliClient, "list_uploader_videos")


@pytest.mark.asyncio
async def test_search_uploaders_retries_after_non_json_response(monkeypatch, tmp_path):
    class FakeResponse:
        def __init__(self, payload=None):
            self.payload = payload

        def json(self):
            if self.payload is None:
                raise ValueError("not json")
            return self.payload

    class FakeClient:
        calls = 0

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            FakeClient.calls += 1
            if FakeClient.calls == 1:
                return FakeResponse()
            return FakeResponse({
                "code": 0,
                "data": {
                    "result": [{
                        "mid": 12345,
                        "uname": "黑鹤001",
                        "upic": "//i0.hdslb.com/avatar.jpg",
                        "fans": 100,
                        "usign": "",
                    }]
                },
            })

    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).search_uploaders("黑鹤001")

    assert len(results) == 1
    assert results[0].name == "黑鹤001"
    assert FakeClient.calls == 2


@pytest.mark.asyncio
async def test_search_uploaders_returns_cached_results_after_transient_failures(monkeypatch, tmp_path):
    class FakeResponse:
        def __init__(self, payload=None):
            self.payload = payload

        def json(self):
            if self.payload is None:
                raise ValueError("not json")
            return self.payload

    class FakeClient:
        calls = 0

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            FakeClient.calls += 1
            if FakeClient.calls == 1:
                return FakeResponse({
                    "code": 0,
                    "data": {
                        "result": [{
                            "mid": 12345,
                            "uname": "黑鹤001",
                            "upic": "//i0.hdslb.com/avatar.jpg",
                            "fans": 100,
                            "usign": "",
                        }]
                    },
                })
            return FakeResponse()

    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)
    client = BiliBiliClient(Settings(download_dir=tmp_path))

    first = await client.search_uploaders("黑鹤001")
    second = await client.search_uploaders("黑鹤001")

    assert len(first) == 1
    assert len(second) == 1
    assert second[0].name == "黑鹤001"
    assert FakeClient.calls == 4


@pytest.mark.asyncio
async def test_list_uploader_videos_returns_cached_results_after_extract_failure(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            if FakeYoutubeDL.calls == 1:
                return {"entries": [{"id": "BV1xx411c7mD"}]}
            raise RuntimeError("blocked")

    class FakeResponse:
        def json(self):
            return {
                "code": 0,
                "data": {
                    "bvid": "BV1xx411c7mD",
                    "title": "投稿标题",
                    "pic": "https://i0.hdslb.com/cover.jpg",
                    "duration": 95,
                    "stat": {"view": 10001},
                    "pubdate": 1710000000,
                },
            }

    class FakeClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            return FakeResponse()

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)
    client = BiliBiliClient(Settings(download_dir=tmp_path))

    first = await client.list_uploader_videos(515231056, page=1, page_size=5)
    second = await client.list_uploader_videos(515231056, page=1, page_size=5)

    assert len(first) == 1
    assert len(second) == 1
    assert second[0].title == "投稿标题"
    assert FakeYoutubeDL.calls == 4


@pytest.mark.asyncio
async def test_list_uploader_videos_signs_space_archive_api_params(monkeypatch, tmp_path):
    captured_params = []

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            params = kwargs.get("params") or {}
            if url.endswith("/x/web-interface/nav"):
                return FakeResponse({
                    "code": 0,
                    "data": {
                        "wbi_img": {
                            "img_url": "https://i0.hdslb.com/bfs/wbi/0123456789abcdef0123456789abcdef.png",
                            "sub_url": "https://i0.hdslb.com/bfs/wbi/fedcba9876543210fedcba9876543210.png",
                        }
                    },
                })
            if url.endswith("/x/space/wbi/arc/search"):
                captured_params.append(params)
                return FakeResponse({"code": -412, "data": {}})
            return FakeResponse({"code": -412, "data": {}})

    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    await BiliBiliClient(Settings(download_dir=tmp_path)).list_uploader_videos(515231056, page=1, uploader_name="黑鹤001")

    assert captured_params
    assert "wts" in captured_params[0]
    assert "w_rid" in captured_params[0]


@pytest.mark.asyncio
async def test_list_uploader_videos_uses_space_archive_api_first(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            return {"entries": []}

    class FakeResponse:
        def json(self):
            return {
                "code": 0,
                "data": {
                    "list": {
                        "vlist": [{
                            "bvid": "BVspace",
                            "title": "空间接口投稿",
                            "pic": "//i0.hdslb.com/cover.jpg",
                            "duration": 95,
                            "play": 10001,
                            "created": 1710000000,
                        }]
                    }
                },
            }

    class FakeClient:
        requested_urls = []

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            self.requested_urls.append(url)
            return FakeResponse()

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_uploader_videos(
        515231056,
        page=1,
        page_size=30,
        uploader_name="黑鹤001",
    )

    assert [video.bvid for video in results] == ["BVspace"]
    assert results[0].title == "空间接口投稿"
    assert FakeYoutubeDL.calls == 0
    assert any(url.endswith("/x/space/wbi/arc/search") for url in FakeClient.requested_urls)


@pytest.mark.asyncio
async def test_list_all_uploader_videos_uses_archive_before_ytdlp(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            return {"entries": [{"id": "BVwrong", "title": "不应优先使用"}]}

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        pages = []

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            if url.endswith("/x/web-interface/nav"):
                return FakeResponse({
                    "code": 0,
                    "data": {
                        "wbi_img": {
                            "img_url": "https://i0.hdslb.com/bfs/wbi/0123456789abcdef0123456789abcdef.png",
                            "sub_url": "https://i0.hdslb.com/bfs/wbi/fedcba9876543210fedcba9876543210.png",
                        }
                    },
                })
            if url.endswith("/x/space/wbi/arc/search"):
                page = int(kwargs["params"]["pn"])
                FakeClient.pages.append(page)
                assert int(kwargs["params"]["ps"]) == 50
                if page == 1:
                    return FakeResponse({"code": 0, "data": {"list": {"vlist": [
                        {"bvid": "BVnew", "title": "最新投稿", "pic": "", "length": "10:58", "play": 8426, "created": 1779473199},
                    ]}}})
                if page == 2:
                    return FakeResponse({"code": 0, "data": {"list": {"vlist": [
                        {"bvid": "BVold", "title": "较早投稿", "pic": "", "length": "43:17", "play": 39329, "created": 1778754415},
                    ]}}})
                return FakeResponse({"code": 0, "data": {"list": {"vlist": []}}})
            return FakeResponse({"code": -412, "data": {}})

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeYoutubeDL.calls == 0
    assert FakeClient.pages == [1, 2, 3]
    assert [video.bvid for video in results] == ["BVnew", "BVold"]
    assert [video.duration for video in results] == ["10:58", "43:17"]


@pytest.mark.asyncio
async def test_list_all_uploader_videos_retries_until_results(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            if FakeYoutubeDL.calls < 4:
                raise RuntimeError("request was banned")
            return {"entries": [{"id": "BVok", "title": "重试成功投稿", "duration": 60}]}

    class FakeResponse:
        def json(self):
            return {"code": -412, "message": "request was banned"}

    class FakeClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            return FakeResponse()

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeYoutubeDL.calls == 4
    assert [video.bvid for video in results] == ["BVok"]


@pytest.mark.asyncio
async def test_list_all_uploader_videos_stops_after_ten_empty_attempts(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            return {"entries": []}

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeYoutubeDL.calls == 10
    assert results == []


@pytest.mark.asyncio
async def test_list_all_uploader_videos_falls_back_to_archive_pages_when_full_extract_blocked(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        calls = 0

        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            FakeYoutubeDL.calls += 1
            raise RuntimeError("Request is rejected by server (352)")

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        pages = []

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            if url.endswith("/x/web-interface/nav"):
                return FakeResponse({
                    "code": 0,
                    "data": {
                        "wbi_img": {
                            "img_url": "https://i0.hdslb.com/bfs/wbi/0123456789abcdef0123456789abcdef.png",
                            "sub_url": "https://i0.hdslb.com/bfs/wbi/fedcba9876543210fedcba9876543210.png",
                        }
                    },
                })
            if url.endswith("/x/space/wbi/arc/search"):
                page = int(kwargs["params"]["pn"])
                FakeClient.pages.append(page)
                if page == 1:
                    return FakeResponse({"code": 0, "data": {"list": {"vlist": [
                        {"bvid": "BVpage1", "title": "第1页投稿", "pic": "", "duration": 60, "play": 1, "created": 1},
                    ]}}})
                if page == 2:
                    return FakeResponse({"code": 0, "data": {"list": {"vlist": [
                        {"bvid": "BVpage2", "title": "第2页投稿", "pic": "", "duration": 95, "play": 10001, "created": 2},
                    ]}}})
                return FakeResponse({"code": 0, "data": {"list": {"vlist": []}}})
            return FakeResponse({"code": -412, "data": {}})

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeYoutubeDL.calls == 0
    assert FakeClient.pages == [1, 2, 3]
    assert [video.bvid for video in results] == ["BVpage1", "BVpage2"]


@pytest.mark.asyncio
async def test_search_uploader_videos_retries_after_transient_ban(monkeypatch, tmp_path):
    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        calls = 0

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            FakeClient.calls += 1
            if FakeClient.calls < 3:
                return FakeResponse({"code": -412, "message": "request was banned"})
            return FakeResponse({"code": 0, "data": {"result": [
                {"mid": 515231056, "bvid": "BVretrySearch", "title": "重试搜索投稿", "pic": "", "duration": "1:00", "play": "1.2万", "pubdate": 1},
            ]}})

    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path))._search_uploader_videos(515231056, "黑鹤001", page=1, page_size=30)

    assert FakeClient.calls == 3
    assert [video.bvid for video in results] == ["BVretrySearch"]


@pytest.mark.asyncio
async def test_list_all_uploader_videos_falls_back_to_uploader_search_when_archive_blocked(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            raise RuntimeError("Request is rejected by server (352)")

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        search_pages = []

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            if url.endswith("/x/web-interface/nav"):
                return FakeResponse({
                    "code": 0,
                    "data": {
                        "wbi_img": {
                            "img_url": "https://i0.hdslb.com/bfs/wbi/0123456789abcdef0123456789abcdef.png",
                            "sub_url": "https://i0.hdslb.com/bfs/wbi/fedcba9876543210fedcba9876543210.png",
                        }
                    },
                })
            if url.endswith("/x/space/wbi/arc/search"):
                return FakeResponse({"code": -352, "message": "风控校验失败"})
            if url.endswith("/x/web-interface/search/type"):
                page = kwargs["params"]["page"]
                FakeClient.search_pages.append(page)
                if page == 1:
                    return FakeResponse({"code": 0, "data": {"result": [
                        {"mid": 515231056, "bvid": "BVsearch1", "title": "搜索投稿1", "pic": "", "duration": "1:00", "play": "1.2万", "pubdate": 1},
                    ]}})
                return FakeResponse({"code": 0, "data": {"result": []}})
            return FakeResponse({"code": -412, "data": {}})

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056, uploader_name="黑鹤001")

    assert FakeClient.search_pages == [1, 2]
    assert [video.bvid for video in results] == ["BVsearch1"]
    assert results[0].view_count == "1.2万"


@pytest.mark.asyncio
async def test_list_all_uploader_videos_enriches_bvid_details_with_retries(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {"entries": [{"id": "BVretry", "title": "BVretry"}]}

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        calls = 0

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            FakeClient.calls += 1
            if FakeClient.calls < 4:
                return FakeResponse({"code": -412, "message": "request was banned"})
            return FakeResponse({
                "code": 0,
                "data": {
                    "bvid": "BVretry",
                    "title": "补齐后的标题",
                    "pic": "https://i0.hdslb.com/cover.jpg",
                    "duration": 95,
                    "stat": {"view": 10001},
                    "pubdate": 1710000000,
                },
            })

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeClient.calls == 4
    assert results[0].title == "补齐后的标题"
    assert results[0].duration == "1:35"
    assert results[0].view_count == "1.0万"


@pytest.mark.asyncio
async def test_list_all_uploader_videos_fetches_details_in_batch_before_single_retry(monkeypatch, tmp_path):
    call_order = []

    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {"entries": [
                {"id": "BVbatch1", "title": "BVbatch1"},
                {"id": "BVbatch2", "title": "BVbatch2"},
            ]}

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        calls_by_bvid = {}

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            bvid = kwargs["params"]["bvid"]
            FakeClient.calls_by_bvid[bvid] = FakeClient.calls_by_bvid.get(bvid, 0) + 1
            call_order.append(bvid)
            if FakeClient.calls_by_bvid[bvid] == 1:
                return FakeResponse({"code": -412, "message": "request was banned"})
            return FakeResponse({
                "code": 0,
                "data": {
                    "bvid": bvid,
                    "title": f"补齐-{bvid}",
                    "pic": "https://i0.hdslb.com/cover.jpg",
                    "duration": 60,
                    "stat": {"view": 100},
                    "pubdate": 1710000000,
                },
            })

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert call_order[:2] == ["BVbatch1", "BVbatch2"]
    assert FakeClient.calls_by_bvid == {"BVbatch1": 2, "BVbatch2": 2}
    assert [video.title for video in results] == ["补齐-BVbatch1", "补齐-BVbatch2"]


@pytest.mark.asyncio
async def test_list_all_uploader_videos_keeps_basic_bvid_after_detail_retries_fail(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {"entries": [{"id": "BVfail", "title": "BVfail"}]}

    class FakeResponse:
        def json(self):
            return {"code": -412, "message": "request was banned"}

    class FakeClient:
        calls = 0

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            FakeClient.calls += 1
            return FakeResponse()

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_all_uploader_videos(515231056)

    assert FakeClient.calls == 12
    assert results[0].bvid == "BVfail"
    assert results[0].title == "BVfail"


@pytest.mark.asyncio
async def test_bilibili_detail_orders_formats_by_highest_quality(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {
                "title": "测试视频",
                "thumbnail": "",
                "description": "",
                "uploader": "UP主",
                "duration": 60,
                "formats": [
                    {"format_id": "720", "ext": "mp4", "height": 720, "width": 1280, "vcodec": "avc", "acodec": "none"},
                    {"format_id": "1080", "ext": "mp4", "height": 1080, "width": 1920, "vcodec": "avc", "acodec": "none"},
                    {"format_id": "480", "ext": "mp4", "height": 480, "width": 854, "vcodec": "avc", "acodec": "none"},
                ],
            }

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)

    detail = await BiliBiliClient(Settings(download_dir=tmp_path)).detail("BV1xx411c7mD")

    assert detail is not None
    assert [fmt.height for fmt in detail.formats] == [1080, 720, 480]


def test_bilibili_settings_keeps_existing_cookie_when_mask_submitted(tmp_path):
    class FakeManager:
        def __init__(self):
            self._settings = Settings(download_dir=tmp_path, bilibili_enabled=True, bilibili_cookies="SESSDATA=real-cookie")

    client = TestClient(app)
    initial_settings = Settings(download_dir=tmp_path, bilibili_enabled=True, bilibili_cookies="SESSDATA=real-cookie")
    initial_settings.save_bilibili_settings(True, "SESSDATA=real-cookie")
    app.state.settings = Settings.load_from_dir(tmp_path)
    app.state.manager = FakeManager()
    resp = client.post(
        "/api/bilibili/settings",
        json={"enabled": True, "cookies": "******"},
    )

    assert resp.status_code == 200
    assert app.state.settings.bilibili_cookies == "SESSDATA=real-cookie"
    assert app.state.manager._settings.bilibili_cookies == "SESSDATA=real-cookie"


def test_bilibili_settings_updates_job_manager_settings(tmp_path):
    class FakeManager:
        def __init__(self):
            self._settings = Settings(download_dir=tmp_path, bilibili_enabled=False, bilibili_cookies="")

    client = TestClient(app)
    app.state.settings = Settings(download_dir=tmp_path, bilibili_enabled=False, bilibili_cookies="")
    app.state.manager = FakeManager()
    resp = client.post(
        "/api/bilibili/settings",
        json={"enabled": True, "cookies": "SESSDATA=fresh-cookie"},
    )

    assert resp.status_code == 200
    assert app.state.manager._settings.bilibili_enabled is True
    assert app.state.manager._settings.bilibili_cookies == "SESSDATA=fresh-cookie"


def test_bilibili_login_check_saves_only_verified_cookies(monkeypatch, tmp_path):
    from ovd.web.app import _bilibili_login_sessions
    from ovd.web.app import app, Settings
    from ovd.api.bilibili_login import LoginResult
    from fastapi.testclient import TestClient
    import ovd.web.app as app_module

    class FakeSettings:
        def __init__(self):
            self.download_dir = tmp_path
            self.saved = None
            self.request_timeout = 10.0
            self.user_agent = "Mozilla/5.0"
            self.max_jobs = 10
            self.bilibili_enabled = True
            self.bilibili_cookies = ""
            self.concurrency = 3
            self.sources = []

        def save_bilibili_settings(self, enabled, cookies):
            self.saved = {"enabled": enabled, "cookies": cookies}
            self.bilibili_enabled = enabled
            self.bilibili_cookies = cookies

    class FakeLogin:
        async def check_login(self, qrcode_key):
            return LoginResult(success=True, cookies="SESSDATA=session-value", message="登录成功！")

        async def verify_cookies(self, cookies):
            return True

    fake_settings = FakeSettings()
    _bilibili_login_sessions.clear()
    _bilibili_login_sessions["session-ok"] = {
        "login": FakeLogin(),
        "qrcode_key": "abc",
        "created_at": 0,
    }

    monkeypatch.setattr(Settings, "load_from_dir", lambda download_dir: fake_settings)
    app.state.settings = fake_settings
    app.state.manager = type("FakeManager", (), {})()

    with TestClient(app) as client:
        response = client.get("/api/bilibili/login/check/session-ok")

    assert response.status_code == 200
    assert response.json() == {
        "success": True,
        "message": "登录成功，Cookies 已保存成功",
        "has_cookies": True,
    }
    assert fake_settings.saved == {"enabled": True, "cookies": "SESSDATA=session-value"}
    assert "session-ok" not in _bilibili_login_sessions


def test_bilibili_login_check_does_not_save_unverified_cookies(monkeypatch, tmp_path):
    from ovd.web.app import _bilibili_login_sessions
    from ovd.web.app import app, Settings
    from ovd.api.bilibili_login import LoginResult
    from fastapi.testclient import TestClient
    import ovd.web.app as app_module

    class FakeSettings:
        def __init__(self):
            self.download_dir = tmp_path
            self.saved = None
            self.request_timeout = 10.0
            self.user_agent = "Mozilla/5.0"
            self.max_jobs = 10
            self.bilibili_enabled = True
            self.bilibili_cookies = ""
            self.concurrency = 3
            self.sources = []

        def save_bilibili_settings(self, enabled, cookies):
            self.saved = {"enabled": enabled, "cookies": cookies}
            self.bilibili_enabled = enabled
            self.bilibili_cookies = cookies

    class FakeLogin:
        async def check_login(self, qrcode_key):
            return LoginResult(success=True, cookies="SESSDATA=session-value", message="登录成功！")

        async def verify_cookies(self, cookies):
            return False

    fake_settings = FakeSettings()
    _bilibili_login_sessions.clear()
    _bilibili_login_sessions["session-bad"] = {
        "login": FakeLogin(),
        "qrcode_key": "abc",
        "created_at": 0,
    }

    app.state.settings = fake_settings
    app.state.manager = type("FakeManager", (), {})()

    with TestClient(app) as client:
        response = client.get("/api/bilibili/login/check/session-bad")

    assert response.status_code == 200
    assert response.json() == {
        "success": False,
        "message": "登录成功但 Cookies 校验失败，请重新扫码",
        "has_cookies": False,
    }
    assert fake_settings.saved is None
    assert "session-bad" not in _bilibili_login_sessions


def test_uploader_download_uses_uploader_folder_and_best_quality_default(tmp_path):
    class FakeManager:
        def list_jobs(self):
            return []

        def enqueue(self, *, video_name, episode_name, url, folder_name=None):
            folder = tmp_path / (folder_name or video_name)
            return DownloadJob(
                id=1,
                video_name=video_name,
                episode_name=episode_name,
                url=url,
                output_path=folder / f"{video_name}.mp4",
                status=JobStatus.QUEUED,
            )

    with TestClient(app) as client:
        app.state.settings = Settings(download_dir=tmp_path, bilibili_enabled=True)
        app.state.manager = FakeManager()
        resp = client.post(
            "/api/bilibili/uploaders/download",
            json={
                "uploader_name": "黑鹤001",
                "videos": [{"bvid": "BV1xx411c7mD", "title": "投稿标题"}],
            },
        )

    assert resp.status_code == 200
    job = resp.json()["jobs"][0]
    assert job["video_name"] == "投稿标题"
    assert job["episode_name"] == "投稿标题"
    assert job["output_path"].endswith("黑鹤001/投稿标题.mp4")
    assert "format=bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" in job["url"]


def test_bilibili_download_uses_best_quality_default(tmp_path):
    class FakeManager:
        def list_jobs(self):
            return []

        def enqueue(self, *, video_name, episode_name, url, folder_name=None):
            return DownloadJob(
                id=1,
                video_name=video_name,
                episode_name=episode_name,
                url=url,
                output_path=tmp_path / f"{episode_name}.mp4",
                status=JobStatus.QUEUED,
            )

    with TestClient(app) as client:
        app.state.settings = Settings(download_dir=tmp_path, bilibili_enabled=True)
        app.state.manager = FakeManager()
        resp = client.post(
            "/api/bilibili/download",
            json={
                "bvid": "BV1xx411c7mD",
                "title": "视频标题",
                "episodes": [1],
            },
        )

    assert resp.status_code == 200
    job = resp.json()["jobs"][0]
    assert "format=bestvideo[height<=1080]+bestaudio/best[height<=1080]/best" in job["url"]


def test_uploader_videos_all_uses_list_all_method_when_available(tmp_path):
    class FakeBiliClient:
        def __init__(self):
            self.used_list_all = False

        async def list_all_uploader_videos(self, mid, uploader_name=""):
            self.used_list_all = True
            return [BiliUploaderVideo("BVall", "全量投稿", "", "1:00", "1", "")]

        async def list_uploader_videos(self, mid, page=1, page_size=30, uploader_name=""):
            return [BiliUploaderVideo("BVpaged", "分页投稿", "", "1:00", "1", "")]

    fake_client = FakeBiliClient()
    with TestClient(app) as client:
        app.state.settings = Settings(download_dir=tmp_path, bilibili_enabled=True)
        app.state.bili_client = fake_client
        resp = client.get("/api/bilibili/uploaders/123/videos?all=true&name=黑鹤001")

    assert resp.status_code == 200
    data = resp.json()
    assert data["count"] == 1
    assert data["items"][0]["bvid"] == "BVall"
    assert fake_client.used_list_all is True


@pytest.mark.asyncio
async def test_list_uploader_videos_uses_search_fallback_when_detail_results_empty(monkeypatch, tmp_path):
    class FakeYoutubeDL:
        def __init__(self, opts):
            pass

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {"entries": [{"id": f"BV{i}"} for i in range(31)]}

    class FakeResponse:
        def __init__(self, payload):
            self.payload = payload

        def json(self):
            return self.payload

    class FakeClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            if url.endswith("/x/web-interface/view"):
                return FakeResponse({"code": -352, "message": "风控校验失败"})
            return FakeResponse({
                "code": 0,
                "data": {
                    "result": [{
                        "mid": 515231056,
                        "bvid": "BVfallback",
                        "title": "兜底投稿",
                        "pic": "//i0.hdslb.com/cover.jpg",
                        "duration": "12:34",
                        "play": 100,
                        "pubdate": 1710000000,
                    }]
                },
            })

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)
    monkeypatch.setattr("ovd.api.bilibili.httpx.AsyncClient", FakeClient)

    results = await BiliBiliClient(Settings(download_dir=tmp_path)).list_uploader_videos(
        515231056,
        page=2,
        uploader_name="黑鹤001",
    )

    assert [video.bvid for video in results] == ["BVfallback"]
    assert results[0].title == "兜底投稿"


@pytest.mark.asyncio
async def test_bilibili_detail_converts_cookie_text_to_cookiefile(monkeypatch, tmp_path):
    captured_opts = {}

    class FakeYoutubeDL:
        def __init__(self, opts):
            captured_opts.update(opts)
            captured_opts["cookiefile_text"] = Path(opts["cookiefile"]).read_text()

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb):
            return False

        def extract_info(self, url, download=False):
            return {
                "id": "BVdetail",
                "title": "详情视频",
                "thumbnail": "https://example.com/cover.jpg",
                "description": "简介",
                "uploader": "UP主",
                "duration": 60,
                "view_count": 100,
                "upload_date": "20260523",
                "formats": [{
                    "format_id": "100026",
                    "ext": "mp4",
                    "height": 1080,
                    "width": 1920,
                    "vcodec": "av01",
                    "acodec": "none",
                }],
            }

    monkeypatch.setattr(bilibili_module.yt_dlp, "YoutubeDL", FakeYoutubeDL)

    cookie_text = f"SESSDATA={'x' * 300}; bili_jct=test-jct"
    client = BiliBiliClient(Settings(download_dir=tmp_path, bilibili_cookies=cookie_text))

    detail = await client.detail("BVdetail")

    assert detail is not None
    cookiefile_text = captured_opts["cookiefile_text"]
    assert "# Netscape HTTP Cookie File" in cookiefile_text
    assert f".bilibili.com\tTRUE\t/\tFALSE\t0\tSESSDATA\t{'x' * 300}" in cookiefile_text
    assert ".bilibili.com\tTRUE\t/\tFALSE\t0\tbili_jct\ttest-jct" in cookiefile_text


def test_retry_job_endpoint_requeues_failed_job(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    job = manager.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    job.status = JobStatus.FAILED
    job.error = "RuntimeError('broken')"
    job.retry_count = 3

    app.state.manager = manager
    client = TestClient(app)

    response = client.post(f"/api/jobs/{job.id}/retry")

    assert response.status_code == 200
    assert response.json() == {"id": job.id, "status": "queued"}
    assert job.status == JobStatus.QUEUED
    assert job.error is None
    assert job.retry_count == 0


def test_retry_job_endpoint_rejects_completed_job(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    job = manager.enqueue(
        video_name="测试视频",
        episode_name="第01集",
        url="https://example.com/x.m3u8",
    )
    job.status = JobStatus.COMPLETED

    app.state.manager = manager
    client = TestClient(app)

    response = client.post(f"/api/jobs/{job.id}/retry")

    assert response.status_code == 400


def test_download_jobs_zip_returns_selected_completed_files(tmp_path):
    import io
    import zipfile

    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    first = manager.enqueue(
        video_name="视频一",
        episode_name="视频一",
        url="https://example.com/1.m3u8",
    )
    first.status = JobStatus.COMPLETED
    first.output_path.write_bytes(b"first-video")
    first.bytes_downloaded = first.output_path.stat().st_size
    second = manager.enqueue(
        video_name="视频二",
        episode_name="视频二",
        url="https://example.com/2.m3u8",
    )
    second.status = JobStatus.COMPLETED
    second.output_path.write_bytes(b"second-video")
    second.bytes_downloaded = second.output_path.stat().st_size

    app.state.manager = manager
    client = TestClient(app)

    response = client.post("/api/jobs/download-zip", json={"ids": [first.id, second.id]})

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/zip"
    assert "attachment" in response.headers["content-disposition"]
    with zipfile.ZipFile(io.BytesIO(response.content)) as zf:
        assert sorted(zf.namelist()) == ["视频一.mp4", "视频二.mp4"]
        assert zf.read("视频一.mp4") == b"first-video"
        assert zf.read("视频二.mp4") == b"second-video"
    assert first.exported is True
    assert second.exported is True
    assert first.output_path.exists()
    assert second.output_path.exists()


def test_download_jobs_zip_deduplicates_repeated_ids(tmp_path):
    import io
    import zipfile

    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    first = manager.enqueue(
        video_name="视频一",
        episode_name="视频一",
        url="https://example.com/1.m3u8",
    )
    first.status = JobStatus.COMPLETED
    first.output_path.write_bytes(b"first-video")
    second = manager.enqueue(
        video_name="视频二",
        episode_name="视频二",
        url="https://example.com/2.m3u8",
    )
    second.status = JobStatus.COMPLETED
    second.output_path.write_bytes(b"second-video")

    app.state.manager = manager
    client = TestClient(app)

    response = client.post("/api/jobs/download-zip", json={"ids": [first.id, second.id, first.id, second.id]})

    assert response.status_code == 200
    with zipfile.ZipFile(io.BytesIO(response.content)) as zf:
        assert sorted(zf.namelist()) == ["视频一.mp4", "视频二.mp4"]


def test_download_job_marks_exported_without_deleting_file(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    job = manager.enqueue(
        video_name="视频一",
        episode_name="视频一",
        url="https://example.com/1.m3u8",
    )
    job.status = JobStatus.COMPLETED
    job.output_path.write_bytes(b"video")

    app.state.manager = manager
    client = TestClient(app)

    response = client.get(f"/api/jobs/{job.id}/download")

    assert response.status_code == 200
    assert job.exported is True
    assert job.output_path.exists()


def test_delete_job_endpoint_removes_exported_file(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    job = manager.enqueue(
        video_name="视频一",
        episode_name="视频一",
        url="https://example.com/1.m3u8",
    )
    job.status = JobStatus.COMPLETED
    job.exported = True
    job.output_path.write_bytes(b"video")

    app.state.manager = manager
    client = TestClient(app)

    response = client.delete(f"/api/jobs/{job.id}")

    assert response.status_code == 200
    assert not job.output_path.exists()


def test_download_jobs_zip_rejects_unfinished_or_missing_files(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    queued = manager.enqueue(
        video_name="未完成视频",
        episode_name="未完成视频",
        url="https://example.com/queued.m3u8",
    )
    missing = manager.enqueue(
        video_name="缺失文件视频",
        episode_name="缺失文件视频",
        url="https://example.com/missing.m3u8",
    )
    missing.status = JobStatus.COMPLETED

    app.state.manager = manager
    client = TestClient(app)

    queued_response = client.post("/api/jobs/download-zip", json={"ids": [queued.id]})
    missing_response = client.post("/api/jobs/download-zip", json={"ids": [missing.id]})
    empty_response = client.post("/api/jobs/download-zip", json={"ids": []})

    assert queued_response.status_code == 400
    assert missing_response.status_code == 404
    assert empty_response.status_code == 400


def test_delete_job_files_endpoint_removes_selected_files(tmp_path):
    from ovd.downloader.jobs import JobManager

    settings = Settings(download_dir=tmp_path, concurrency=1)
    manager = JobManager(settings)
    first = manager.enqueue(
        video_name="视频一",
        episode_name="视频一",
        url="https://example.com/1.m3u8",
    )
    first.status = JobStatus.COMPLETED
    first.output_path.write_bytes(b"first-video")
    second = manager.enqueue(
        video_name="视频二",
        episode_name="视频二",
        url="https://example.com/2.m3u8",
    )
    second.status = JobStatus.COMPLETED
    second.output_path.write_bytes(b"second-video")

    app.state.manager = manager
    client = TestClient(app)

    response = client.post("/api/jobs/delete-files", json={"ids": [first.id, second.id]})

    assert response.status_code == 200
    assert response.json() == {"deleted_count": 2, "ids": [first.id, second.id]}
    assert not first.output_path.exists()
    assert not second.output_path.exists()
