"""Bilibili 客户端: 搜索、获取视频详情、分集列表。

使用 httpx 调用 Bilibili 公开 API 搜索，yt-dlp 用于下载。
"""

from __future__ import annotations

import asyncio
import hashlib
import time
import urllib.parse
from dataclasses import dataclass
from typing import Any

import httpx
import yt_dlp

try:
    from ovd.config import Settings
except ImportError:
    from ..config import Settings


@dataclass(frozen=True)
class BiliVideoFormat:
    """视频格式（画质）。"""

    format_id: str
    ext: str
    quality: str  # "1080P", "720P", "4K" 等
    width: int | None
    height: int | None
    video_format: str | None  # 视频编码格式
    audio_format: str | None  # 音频编码格式
    has_video: bool
    has_audio: bool


@dataclass(frozen=True)
class BiliEpisode:
    """分P视频（单P视频只有一集）。"""

    page: int  # 第几分P
    name: str  # "第1P" 或分P标题
    cid: int | None
    bvid: str
    url: str  # 播放页面 URL


@dataclass(frozen=True)
class BiliVideoDetail:
    """Bilibili 视频详情。"""

    bvid: str
    title: str
    pic: str  # 封面图
    desc: str
    uploader: str
    duration: int  # 秒
    view_count: int | None
    pub_date: str | None  # 发布日期
    episodes: tuple[BiliEpisode, ...]  # 分P列表
    formats: tuple[BiliVideoFormat, ...]  # 可用画质


@dataclass(frozen=True)
class BiliSearchResult:
    """搜索结果。"""

    bvid: str
    title: str
    pic: str
    uploader: str
    duration: str  # 时长显示 "12:34"
    view_count: str  # 播放量显示 "12.3万"
    pubdate: str  # 发布时间


@dataclass(frozen=True)
class BiliUploaderResult:
    """UP 主搜索结果。"""

    mid: int
    name: str
    face: str
    fans: str
    sign: str


@dataclass(frozen=True)
class BiliUploaderVideo:
    """UP 主投稿视频。"""

    bvid: str
    title: str
    pic: str
    duration: str
    view_count: str
    pubdate: str


def _clean_html(text: str) -> str:
    """清理 HTML 标签。"""
    import re
    return re.sub(r'<[^>]+>', '', text or '').strip()


def _format_duration(seconds: int) -> str:
    """格式化时长显示。"""
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    if h > 0:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m}:{s:02d}"


def _format_view_count(count: int) -> str:
    """格式化播放量显示。"""
    if count >= 10000:
        return f"{count / 10000:.1f}万"
    return str(count)


def _format_maybe_text_view_count(value: Any) -> str:
    if isinstance(value, str):
        return value
    return _format_view_count(int(value or 0))


def _normalize_url(url: str) -> str:
    if url.startswith("//"):
        return "https:" + url
    return url


def _bilibili_cookie_text_to_netscape(cookies: str) -> str:
    if cookies.lstrip().startswith("# Netscape HTTP Cookie File"):
        return cookies
    lines = ["# Netscape HTTP Cookie File"]
    for part in cookies.split(";"):
        part = part.strip()
        if not part or "=" not in part:
            continue
        name, value = part.split("=", 1)
        lines.append(f".bilibili.com\tTRUE\t/\tFALSE\t0\t{name}\t{value}")
    return "\n".join(lines) + "\n"


def _parse_uploader_item(item: dict[str, Any]) -> BiliUploaderResult | None:
    mid = int(item.get("mid") or 0)
    if mid <= 0:
        return None
    return BiliUploaderResult(
        mid=mid,
        name=_clean_html(item.get("uname", "")),
        face=_normalize_url(item.get("upic", "") or item.get("face", "")),
        fans=_format_view_count(int(item.get("fans") or 0)),
        sign=_clean_html(item.get("usign", "") or item.get("sign", "")),
    )


def _parse_uploader_video(item: dict[str, Any]) -> BiliUploaderVideo | None:
    bvid = item.get("bvid", "")
    if not bvid:
        return None
    duration = item.get("duration") or item.get("length") or 0
    duration_text = duration if isinstance(duration, str) else _format_duration(int(duration))
    return BiliUploaderVideo(
        bvid=bvid,
        title=_clean_html(item.get("title", "")) or bvid,
        pic=_normalize_url(item.get("pic", "")),
        duration=duration_text,
        view_count=_format_maybe_text_view_count(item.get("play") or item.get("stat", {}).get("view") or 0),
        pubdate=str(item.get("created") or item.get("pubdate") or ""),
    )


def _parse_view_video(item: dict[str, Any]) -> BiliUploaderVideo | None:
    bvid = item.get("bvid", "")
    if not bvid:
        return None
    return BiliUploaderVideo(
        bvid=bvid,
        title=_clean_html(item.get("title", "")) or bvid,
        pic=_normalize_url(item.get("pic", "")),
        duration=_format_duration(int(item.get("duration") or 0)),
        view_count=_format_view_count(int(item.get("stat", {}).get("view") or 0)),
        pubdate=str(item.get("pubdate") or ""),
    )


class _QuietYtdlpLogger:
    def debug(self, msg: str) -> None:
        pass

    def info(self, msg: str) -> None:
        pass

    def warning(self, msg: str) -> None:
        pass

    def error(self, msg: str) -> None:
        pass


class BiliBiliClient:
    """Bilibili 异步客户端。"""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._base_url = "https://api.bilibili.com"
        self._headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "https://www.bilibili.com/",
            "Origin": "https://www.bilibili.com",
            "Accept": "application/json, text/plain, */*",
            "Accept-Language": "zh-CN,zh;q=0.9",
        }
        # 如果配置了 cookies，添加到 headers
        if settings.bilibili_cookies:
            self._headers["Cookie"] = settings.bilibili_cookies
        self._uploader_search_cache: dict[tuple[str, int, int], tuple[float, list[BiliUploaderResult]]] = {}
        self._uploader_videos_cache: dict[tuple[int, int, int], tuple[float, list[BiliUploaderVideo]]] = {}
        self._wbi_key_cache: tuple[float, str] | None = None

    async def _get_wbi_key(self) -> str:
        if self._wbi_key_cache and time.time() - self._wbi_key_cache[0] < 600:
            return self._wbi_key_cache[1]
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            resp = await client.get(f"{self._base_url}/x/web-interface/nav", headers=self._headers)
            data = resp.json()
        wbi_img = data.get("data", {}).get("wbi_img", {})
        lookup = ""
        for url in (wbi_img.get("img_url", ""), wbi_img.get("sub_url", "")):
            filename = url.rsplit("/", 1)[-1].split(".", 1)[0]
            lookup += filename
        mixin_key_enc_tab = [
            46, 47, 18, 2, 53, 8, 23, 32,
            15, 50, 10, 31, 58, 3, 45, 35,
            27, 43, 5, 49, 33, 9, 42, 19,
            29, 28, 14, 39, 12, 38, 41, 13,
            37, 48, 7, 16, 24, 55, 40, 61,
            26, 17, 0, 1, 60, 51, 30, 4,
            22, 25, 54, 21, 56, 59, 6, 63,
            57, 62, 11, 36, 20, 34, 44, 52,
        ]
        key = "".join(lookup[i] for i in mixin_key_enc_tab if i < len(lookup))[:32]
        self._wbi_key_cache = (time.time(), key)
        return key

    async def _sign_wbi(self, params: dict[str, Any]) -> dict[str, Any]:
        signed = dict(params)
        signed["wts"] = round(time.time())
        signed = {
            key: "".join(ch for ch in str(value) if ch not in "!'()*")
            for key, value in sorted(signed.items())
        }
        query = urllib.parse.urlencode(signed)
        signed["w_rid"] = hashlib.md5(f"{query}{await self._get_wbi_key()}".encode()).hexdigest()
        return signed

    async def search(self, keyword: str, page: int = 1, page_size: int = 20) -> list[BiliSearchResult]:
        """搜索 Bilibili 视频（使用公开 Web API）。"""
        keyword = (keyword or '').strip()
        if not keyword:
            return []

        try:
            async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
                # 使用 Bilibili 公开搜索 API
                url = f"{self._base_url}/x/web-interface/search/type"
                params = {
                    "search_type": "video",
                    "keyword": keyword,
                    "page": page,
                    "page_size": page_size,
                }
                resp = await client.get(url, headers=self._headers, params=params)
                data = resp.json()

                if data.get("code") != 0:
                    return []

                results = []
                for item in data.get("data", {}).get("result", []):
                    bvid = item.get("bvid", "")
                    if not bvid:
                        continue

                    results.append(BiliSearchResult(
                        bvid=bvid,
                        title=_clean_html(item.get("title", "")),
                        pic="https:" + item.get("pic", "") if item.get("pic", "").startswith("//") else item.get("pic", ""),
                        uploader=item.get("author", ""),
                        duration=item.get("duration", ""),
                        view_count=_format_view_count(item.get("play", 0)),
                        pubdate=str(item.get("pubdate", "")),
                    ))

                return results
        except Exception:
            return []

    async def search_uploaders(self, keyword: str, page: int = 1, page_size: int = 20) -> list[BiliUploaderResult]:
        """按名称搜索 UP 主。"""
        keyword = (keyword or '').strip()
        if not keyword:
            return []

        cache_key = (keyword, page, page_size)
        cached = self._uploader_search_cache.get(cache_key)

        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            url = f"{self._base_url}/x/web-interface/search/type"
            params = {
                "search_type": "bili_user",
                "keyword": keyword,
                "page": page,
                "page_size": page_size,
            }
            for attempt in range(3):
                try:
                    resp = await client.get(url, headers=self._headers, params=params)
                    data = resp.json()
                    if data.get("code") != 0:
                        if attempt < 2:
                            await asyncio.sleep(0.5 * (attempt + 1))
                            continue
                        if cached and time.time() - cached[0] < 600:
                            return cached[1]
                        return []

                    results = []
                    for item in data.get("data", {}).get("result", []):
                        uploader = _parse_uploader_item(item)
                        if uploader is not None:
                            results.append(uploader)
                    if results:
                        self._uploader_search_cache[cache_key] = (time.time(), results)
                    return results
                except Exception:
                    if attempt < 2:
                        await asyncio.sleep(0.5 * (attempt + 1))
                        continue
                    if cached and time.time() - cached[0] < 600:
                        return cached[1]
                    return []
        if cached and time.time() - cached[0] < 600:
            return cached[1]
        return []

    async def list_all_uploader_videos(self, mid: int, uploader_name: str = "") -> list[BiliUploaderVideo]:
        """一次性尽量获取 UP 主全部投稿视频。"""
        if mid <= 0:
            return []

        def _extract_all() -> list[BiliUploaderVideo]:
            url = f"https://space.bilibili.com/{mid}/video"
            ydl_opts: dict[str, Any] = {
                "quiet": True,
                "no_warnings": True,
                "no_color": True,
                "logger": _QuietYtdlpLogger(),
                "extract_flat": True,
                "playlistend": 10000,
            }
            if self._settings.bilibili_cookies:
                import os
                import tempfile
                fd, path = tempfile.mkstemp(suffix=".txt")
                try:
                    with os.fdopen(fd, "w") as f:
                        f.write(self._settings.bilibili_cookies)
                    ydl_opts["cookiefile"] = path
                except Exception:
                    pass
            for _ in range(10):
                try:
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        info = ydl.extract_info(url, download=False)
                except Exception:
                    continue

                results = []
                seen = set()
                for item in (info.get("entries", []) if info else []):
                    bvid = item.get("id") or item.get("url") or ""
                    if not bvid.startswith("BV") or bvid in seen:
                        continue
                    seen.add(bvid)
                    duration = item.get("duration") or 0
                    duration_text = duration if isinstance(duration, str) else _format_duration(int(duration))
                    view_count = item.get("view_count") or item.get("view") or item.get("play") or 0
                    results.append(BiliUploaderVideo(
                        bvid=bvid,
                        title=_clean_html(item.get("title", "")) or bvid,
                        pic=_normalize_url(item.get("thumbnail", "") or item.get("pic", "")),
                        duration=duration_text,
                        view_count=_format_view_count(int(view_count or 0)),
                        pubdate=str(item.get("timestamp") or item.get("upload_date") or item.get("created") or ""),
                    ))
                if results:
                    return results
            return []

        basics = []
        seen = set()
        for page in range(1, 101):
            page_videos = await self._fetch_space_archive_videos(mid, page=page, page_size=50)
            if not page_videos:
                break
            for video in page_videos:
                if video.bvid in seen:
                    continue
                seen.add(video.bvid)
                basics.append(video)
        if not basics:
            loop = asyncio.get_event_loop()
            basics = await loop.run_in_executor(None, _extract_all)
        if not basics and uploader_name.strip():
            for page in range(1, 101):
                page_videos = await self._search_uploader_videos(mid, uploader_name, page=page, page_size=30)
                if not page_videos:
                    break
                for video in page_videos:
                    if video.bvid in seen:
                        continue
                    seen.add(video.bvid)
                    basics.append(video)
        if not basics:
            return []

        async def _fetch_detail_once(client: httpx.AsyncClient, basic: BiliUploaderVideo) -> BiliUploaderVideo | None:
            try:
                resp = await client.get(
                    f"{self._base_url}/x/web-interface/view",
                    headers=self._headers,
                    params={"bvid": basic.bvid},
                )
                data = resp.json()
                if data.get("code") != 0:
                    return None
                return _parse_view_video(data.get("data", {}))
            except Exception:
                return None

        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            enriched: dict[str, BiliUploaderVideo] = {}
            pending = list(basics)
            for _ in range(10):
                if not pending:
                    break
                videos = await asyncio.gather(*(_fetch_detail_once(client, basic) for basic in pending))
                next_pending = []
                for basic, video in zip(pending, videos):
                    if video is None:
                        next_pending.append(basic)
                    else:
                        enriched[basic.bvid] = video
                pending = next_pending
            return [enriched.get(basic.bvid, basic) for basic in basics]

    async def _fetch_space_archive_videos(self, mid: int, page: int, page_size: int) -> list[BiliUploaderVideo]:
        try:
            async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
                params = await self._sign_wbi({
                    "mid": mid,
                    "pn": page,
                    "ps": page_size,
                    "order": "pubdate",
                })
                resp = await client.get(
                    f"{self._base_url}/x/space/wbi/arc/search",
                    headers=self._headers,
                    params=params,
                )
                data = resp.json()
                if data.get("code") != 0:
                    return []
                videos = []
                for item in data.get("data", {}).get("list", {}).get("vlist", []):
                    video = _parse_uploader_video(item)
                    if video is not None:
                        videos.append(video)
                return videos
        except Exception:
            return []

    async def _search_uploader_videos(self, mid: int, uploader_name: str, page: int, page_size: int) -> list[BiliUploaderVideo]:
        if not uploader_name.strip():
            return []
        for _ in range(10):
            try:
                async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
                    resp = await client.get(
                        f"{self._base_url}/x/web-interface/search/type",
                        headers=self._headers,
                        params={
                            "search_type": "video",
                            "keyword": uploader_name.strip(),
                            "page": page,
                            "page_size": page_size,
                        },
                    )
                    data = resp.json()
                    if data.get("code") != 0:
                        continue
                    videos = []
                    for item in data.get("data", {}).get("result", []):
                        if int(item.get("mid") or 0) != mid:
                            continue
                        video = _parse_uploader_video(item)
                        if video is not None:
                            videos.append(video)
                    return videos
            except Exception:
                continue
        return []

    async def list_uploader_videos(
        self,
        mid: int,
        page: int = 1,
        page_size: int = 30,
        uploader_name: str = "",
    ) -> list[BiliUploaderVideo]:
        """获取 UP 主投稿视频列表。"""
        if mid <= 0:
            return []

        cache_key = (mid, page, page_size)
        cached = self._uploader_videos_cache.get(cache_key)

        def _extract_bvids() -> list[str]:
            url = f"https://space.bilibili.com/{mid}/video"
            ydl_opts: dict[str, Any] = {
                "quiet": True,
                "no_warnings": True,
                "no_color": True,
                "logger": _QuietYtdlpLogger(),
                "extract_flat": True,
                "playlistend": max(1, page) * page_size,
            }
            if self._settings.bilibili_cookies:
                import os
                import tempfile
                fd, path = tempfile.mkstemp(suffix=".txt")
                try:
                    with os.fdopen(fd, "w") as f:
                        f.write(self._settings.bilibili_cookies)
                    ydl_opts["cookiefile"] = path
                except Exception:
                    pass

            for _ in range(3):
                try:
                    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                        info = ydl.extract_info(url, download=False)
                    entries = info.get("entries", []) if info else []
                    start = (max(1, page) - 1) * page_size
                    bvids = []
                    for item in entries[start:start + page_size]:
                        bvid = item.get("id") or item.get("url") or ""
                        if bvid.startswith("BV"):
                            bvids.append(bvid)
                    if bvids:
                        return bvids
                except Exception:
                    continue
            return []

        async def _search_uploader_videos() -> list[BiliUploaderVideo]:
            if not uploader_name.strip():
                return []
            try:
                async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
                    resp = await client.get(
                        f"{self._base_url}/x/web-interface/search/type",
                        headers=self._headers,
                        params={
                            "search_type": "video",
                            "keyword": uploader_name.strip(),
                            "page": page,
                            "page_size": page_size,
                        },
                    )
                    data = resp.json()
                    if data.get("code") != 0:
                        return []
                    videos = []
                    for item in data.get("data", {}).get("result", []):
                        if int(item.get("mid") or 0) != mid:
                            continue
                        video = _parse_uploader_video(item)
                        if video is not None:
                            videos.append(video)
                    return videos
            except Exception:
                return []

        space_archive_videos = await self._fetch_space_archive_videos(mid, page=page, page_size=page_size)
        if space_archive_videos:
            self._uploader_videos_cache[cache_key] = (time.time(), space_archive_videos)
            return space_archive_videos

        loop = asyncio.get_event_loop()
        bvids = await loop.run_in_executor(None, _extract_bvids)
        if not bvids:
            fallback = await _search_uploader_videos()
            if fallback:
                self._uploader_videos_cache[cache_key] = (time.time(), fallback)
                return fallback
            if cached and time.time() - cached[0] < 600:
                return cached[1]
            return []

        results = []
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            for bvid in bvids:
                try:
                    resp = await client.get(
                        f"{self._base_url}/x/web-interface/view",
                        headers=self._headers,
                        params={"bvid": bvid},
                    )
                    data = resp.json()
                    if data.get("code") != 0:
                        continue
                    video = _parse_view_video(data.get("data", {}))
                    if video is not None:
                        results.append(video)
                except Exception:
                    continue
        if results:
            self._uploader_videos_cache[cache_key] = (time.time(), results)
            return results
        fallback = await _search_uploader_videos()
        if fallback:
            self._uploader_videos_cache[cache_key] = (time.time(), fallback)
            return fallback
        if cached and time.time() - cached[0] < 600:
            return cached[1]
        return []

    async def detail(self, bvid: str) -> BiliVideoDetail | None:
        """获取视频详情，包括分P和可用画质。"""
        if not bvid:
            return None

        # 使用 yt-dlp 提取详情（更可靠）
        def _do_extract():
            url = f"https://www.bilibili.com/video/{bvid}"

            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "extract_flat": False,
                "noplaylist": True,
            }

            # 添加 cookies
            if self._settings.bilibili_cookies:
                # 写入临时文件供 yt-dlp 使用
                import tempfile
                import os
                fd, path = tempfile.mkstemp(suffix=".txt")
                try:
                    with os.fdopen(fd, "w") as f:
                        f.write(_bilibili_cookie_text_to_netscape(self._settings.bilibili_cookies))
                    ydl_opts["cookiefile"] = path
                except Exception:
                    pass

            try:
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(url, download=False)
                    if not info:
                        return None

                    # 处理分P
                    episodes = []
                    entries = info.get("entries", [])
                    if entries:
                        # 多P视频
                        for i, e in enumerate(entries, 1):
                            episodes.append(BiliEpisode(
                                page=i,
                                name=e.get("title", f"第{i}P"),
                                cid=e.get("cid"),
                                bvid=bvid,
                                url=e.get("webpage_url", url),
                            ))
                    else:
                        # 单P视频
                        episodes.append(BiliEpisode(
                            page=1,
                            name=info.get("title", "第1P"),
                            cid=info.get("cid"),
                            bvid=bvid,
                            url=url,
                        ))

                    # 处理可用画质
                    formats = []
                    seen = set()
                    for f in info.get("formats", []):
                        fid = f.get("format_id", "")
                        if fid in seen:
                            continue
                        seen.add(fid)

                        height = f.get("height")
                        if height:
                            quality = f"{height}P"
                        else:
                            quality = f.get("format_note", "未知画质")

                        formats.append(BiliVideoFormat(
                            format_id=fid,
                            ext=f.get("ext", "mp4"),
                            quality=quality,
                            width=f.get("width"),
                            height=height,
                            video_format=f.get("vcodec"),
                            audio_format=f.get("acodec"),
                            has_video=f.get("vcodec") != "none" if f.get("vcodec") else True,
                            has_audio=f.get("acodec") != "none" if f.get("acodec") else True,
                        ))

                    # 优先排序：最高可用画质在前，同画质优先音视频齐全
                    formats.sort(key=lambda f: (
                        f.height or 0,
                        f.has_video and f.has_audio,
                    ), reverse=True)

                    return BiliVideoDetail(
                        bvid=bvid,
                        title=_clean_html(info.get("title", "")),
                        pic=info.get("thumbnail", ""),
                        desc=_clean_html(info.get("description", "")),
                        uploader=info.get("uploader", ""),
                        duration=info.get("duration", 0) or 0,
                        view_count=info.get("view_count"),
                        pub_date=str(info.get("upload_date", "")),
                        episodes=tuple(episodes),
                        formats=tuple(formats),
                    )
            except Exception as e:
                return None

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _do_extract)

    async def get_download_urls(self, bvid: str, page: int = 1, format_id: str | None = None) -> tuple[str, str]:
        """获取指定分P和画质的视频+音频下载 URL。

        Returns: (video_url, audio_url)
        audio_url 可能为空（某些格式音视频合一）
        """
        url = f"https://www.bilibili.com/video/{bvid}?p={page}"

        def _do_extract():
            try:
                ydl_opts = {
                    "quiet": True,
                    "no_warnings": True,
                }
                if format_id:
                    ydl_opts["format"] = format_id
                else:
                    # 默认：最佳画质 + 音频
                    ydl_opts["format"] = "bestvideo+bestaudio/best"

                # 添加 cookies
                if self._settings.bilibili_cookies:
                    import tempfile
                    import os
                    fd, path = tempfile.mkstemp(suffix=".txt")
                    try:
                        with os.fdopen(fd, "w") as f:
                            f.write(self._settings.bilibili_cookies)
                        ydl_opts["cookiefile"] = path
                    except Exception:
                        pass

                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    info = ydl.extract_info(url, download=False)
                    if not info:
                        return ("", "")

                    # 获取请求的格式 URL
                    if format_id:
                        for f in info.get("formats", []):
                            if f.get("format_id") == format_id:
                                return (f.get("url", ""), "")
                    else:
                        # 最佳画质自动选择
                        return (info.get("url", ""), "")

                    # 回退：第一个可用格式
                    for f in info.get("formats", []):
                        if f.get("url"):
                            return (f.get("url", ""), "")

                    return ("", "")
            except Exception:
                return ("", "")

        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, _do_extract)


# 测试
if __name__ == '__main__':
    import asyncio
    from ovd.config import Settings

    async def test():
        settings = Settings.load()
        client = BiliBiliClient(settings)

        # 测试搜索
        results = await client.search('Python 教程')
        print(f'Search results: {len(results)}')
        for r in results[:3]:
            print(f'  - {r.title} ({r.bvid})')

        # 测试详情
        if results:
            detail = await client.detail(results[0].bvid)
            if detail:
                print(f'Detail: {detail.title}')
                print(f'Episodes: {len(detail.episodes)}')
                print(f'Formats: {len(detail.formats)}')

    asyncio.run(test())
