"""FastAPI 入口。

提供:
- GET /                   首页 (静态)
- GET /api/search?wd=…    搜索
- GET /api/detail?…       获取分集
- POST /api/download      入队下载 (单集 or 批量)
- GET /api/jobs           列出所有任务
- POST /api/jobs/{id}/cancel  取消队列中的任务
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
from typing import AsyncIterator
import tempfile
import time
import zipfile

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

import sys
from pathlib import Path

# PyInstaller 兼容：优先绝对导入
try:
    from ovd import __version__
    from ovd.api import MacCMSClient, BiliBiliClient
    from ovd.api.bilibili_login import BiliBiliLogin
    from ovd.config import Settings, Source
    from ovd.downloader import JobManager
    from ovd.downloader.jobs import BILIBILI_DEFAULT_FORMAT, JobStatus
    from ovd.storage import LocalStorage
except ImportError:
    from .. import __version__
    from ..api import MacCMSClient, BiliBiliClient
    from ..api.bilibili_login import BiliBiliLogin
    from ..config import Settings, Source
    from ..downloader import JobManager
    from ..downloader.jobs import BILIBILI_DEFAULT_FORMAT, JobStatus
    from ..storage import LocalStorage

# PyInstaller 兼容：从临时目录加载静态文件
if getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS'):
    STATIC_DIR = Path(sys._MEIPASS) / 'ovd' / 'static'
else:
    STATIC_DIR = Path(__file__).resolve().parent.parent / 'static'


class EpisodeIn(BaseModel):
    name: str
    url: str


class DownloadIn(BaseModel):
    video_name: str = Field(..., min_length=1)
    episodes: list[EpisodeIn] = Field(..., min_length=1)


class FavoriteIn(BaseModel):
    source_name: str
    vod_id: int
    name: str
    pic: str = ""
    remarks: str = ""
    year: str = ""
    area: str = ""
    type_name: str = ""


class SourceIn(BaseModel):
    name: str
    api: str


class SourceUpdateIn(BaseModel):
    old_name: str
    new_name: str
    new_api: str


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = Settings.load()
    client = MacCMSClient(settings)
    bili_client = BiliBiliClient(settings)  # Bilibili 客户端
    manager = JobManager(settings)
    storage = LocalStorage(settings.download_dir)
    await manager.start()
    app.state.settings = settings
    app.state.client = client
    app.state.bili_client = bili_client
    app.state.manager = manager
    app.state.storage = storage
    try:
        yield
    finally:
        await manager.stop()
        await client.aclose()


app = FastAPI(title="online-video-downloader", version=__version__, lifespan=lifespan)


# --- 页面 ---------------------------------------------------------------

@app.get("/", include_in_schema=False)
async def index() -> FileResponse:
    return FileResponse(
        STATIC_DIR / "index.html",
        headers={
            "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )


# 自定义静态文件中间件，添加反缓存头
from fastapi import Response
from starlette.staticfiles import StaticFiles as _StaticFiles

class NoCacheStaticFiles(_StaticFiles):
    async def get_response(self, path: str, scope):
        response = await super().get_response(path, scope)
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
        return response

app.mount("/static", NoCacheStaticFiles(directory=STATIC_DIR), name="static")


# --- API ----------------------------------------------------------------

@app.get("/api/version")
async def api_version() -> dict:
    settings = getattr(app.state, 'settings', None) or Settings.load()
    return {
        "version": __version__,
        "download_dir": str(settings.download_dir),
        "sources": [{"name": s.name, "api": s.api} for s in settings.sources],
    }


@app.get("/api/search")
async def api_search(wd: str, source: str | None = None) -> dict:
    client: MacCMSClient = app.state.client
    storage: LocalStorage = app.state.storage
    items = await client.search(wd)

    # 记录搜索历史
    if wd.strip():
        storage.add_search_history(wd)

    # 按数据源筛选
    if source:
        items = [v for v in items if v.source_name == source]

    return {
        "keyword": wd,
        "source": source,
        "count": len(items),
        "items": [
            {
                "source_name": v.source_name,
                "vod_id": v.vod_id,
                "name": v.name,
                "pic": v.pic,
                "remarks": v.remarks,
                "year": v.year,
                "area": v.area,
                "type_name": v.type_name,
                "quality": _detect_quality(v),
            }
            for v in items
        ],
    }


def _detect_quality(v) -> str:
    """根据源信息推断画质"""
    text = (v.source_name + v.remarks + v.type_name).lower()
    if any(k in text for k in ['1080', '1080p', '蓝光', 'bluray', '4k', '超清']):
        return '1080P'
    if any(k in text for k in ['720', '720p', '高清']):
        return '720P'
    return '高清'


async def _validate_source_url(client, url: str) -> bool:
    """验证播放链接是否有效"""
    try:
        resp = await client.get(url, follow_redirects=True)
        if resp.status_code != 200:
            return False
        content_type = resp.headers.get("content-type", "")
        if "html" in content_type.lower():
            return False
        # 检查内容是否为 m3u8 格式
        text = resp.text.strip()
        return text.startswith("#")
    except Exception:
        return False


@app.get("/api/detail")
async def api_detail(source_name: str, vod_id: int) -> dict:
    client: MacCMSClient = app.state.client
    detail = await client.detail(source_name, vod_id)
    if detail is None:
        raise HTTPException(status_code=404, detail="未找到该剧集")

    # 验证播放源可用性（验证第1集链接）
    httpx_client = client._client
    valid_sources = []
    for s in detail.play_sources:
        if s.episodes and await _validate_source_url(httpx_client, s.episodes[0].url):
            valid_sources.append(s)

    if not valid_sources:
        raise HTTPException(status_code=404, detail="该剧集所有播放源均已失效，请换其他剧集")

    best = valid_sources[0]
    return {
        "summary": {
            "source_name": detail.summary.source_name,
            "vod_id": detail.summary.vod_id,
            "name": detail.summary.name,
            "pic": detail.summary.pic,
            "remarks": detail.summary.remarks,
            "year": detail.summary.year,
            "area": detail.summary.area,
            "type_name": detail.summary.type_name,
        },
        "play_sources": [
            {
                "flag": s.flag,
                "is_m3u8": s.is_m3u8,
                "is_recommended": (s is best),
                "episodes": [{"name": e.name, "url": e.url} for e in s.episodes],
            }
            for s in valid_sources
        ],
    }


@app.post("/api/download")
async def api_download(payload: DownloadIn) -> dict:
    settings: Settings = app.state.settings
    manager: JobManager = app.state.manager
    current_jobs = manager.list_jobs()
    if len(current_jobs) + len(payload.episodes) > settings.max_jobs:
        raise HTTPException(
            status_code=400,
            detail=f"下载记录最多同时保留{settings.max_jobs}条，请先删除已下载的记录"
        )
    jobs = manager.enqueue_many(
        video_name=payload.video_name,
        episodes=[(e.name, e.url) for e in payload.episodes],
    )
    return {"queued": len(jobs), "jobs": [j.to_dict() for j in jobs]}


import subprocess
from pathlib import Path

@app.post("/api/open-folder")
async def api_open_folder(path: str) -> dict:
    """打开文件所在目录"""
    try:
        import os
        import platform
        import subprocess

        # 关键：确保路径是原始字符串，不被转义
        # 使用 Path.resolve() 获取绝对路径，避免任何转义问题
        p = Path(path).resolve().parent
        if not p.exists():
            return {"success": False, "error": f"目录不存在: {p}"}

        system = platform.system()
        abs_path = str(p)

        # 检测 WSL 环境
        is_wsl = False
        if system == 'Linux':
            wsl_marker = Path('/proc/sys/fs/binfmt_misc/WSLInterop')
            if wsl_marker.exists() or str(p).startswith('/mnt/'):
                is_wsl = True

        if system == 'Windows':
            # 原生 Windows - 直接使用 Path 对象，避免任何字符串转义问题
            try:
                # 直接传 Path 对象，不转字符串
                os.startfile(p)
                return {"success": True, "path": abs_path}
            except Exception as e1:
                # 备选：使用 subprocess，路径参数用原始字节
                try:
                    # 使用列表形式，shell=False，确保参数不被解析
                    subprocess.run(
                        ['explorer.exe', str(p)],
                        shell=False,
                        timeout=10
                    )
                    return {"success": True, "path": abs_path}
                except Exception as e2:
                    return {"success": False, "error": f"{str(e1)} | {str(e2)}"}
        elif is_wsl:
            # WSL 环境 - 使用 wslpath 转换为 Windows 路径
            try:
                result = subprocess.run(
                    ['wslpath', '-w', str(p)],
                    capture_output=True, text=True, check=True
                )
                win_path = result.stdout.strip()
            except Exception:
                # wslpath 不可用时手动转换
                win_path = str(p)
                if win_path.startswith('/mnt/'):
                    drive = win_path[5]
                    win_path = drive.upper() + ':' + win_path[6:]
                    win_path = win_path.replace('/', '\\')

            # 最简单直接：使用 explorer.exe 打开，WSL 会自动桥接
            # 注意：必须用 shell=True 才能正确调用 Windows 程序
            try:
                subprocess.run(f'explorer.exe "{win_path}"', shell=True, timeout=10)
                return {"success": True, "path": win_path}
            except Exception as e1:
                # 备选：使用 cmd.exe
                cmd_paths = [
                    '/mnt/c/Windows/System32/cmd.exe',
                    '/mnt/d/Windows/System32/cmd.exe',
                ]
                for cmd_path in cmd_paths:
                    if Path(cmd_path).exists():
                        try:
                            subprocess.run(
                                [cmd_path, '/c', 'start', '', win_path],
                                check=True,
                                timeout=5
                            )
                            return {"success": True, "path": win_path}
                        except Exception:
                            continue
                return {"success": False, "error": str(e1)}
        elif system == 'Darwin':  # macOS
            subprocess.run(['open', str(p)], check=True)
            return {"success": True, "path": str(p)}
        else:  # Linux (非 WSL)
            try:
                subprocess.run(['xdg-open', str(p)], check=True)
                return {"success": True, "path": str(p)}
            except Exception:
                return {"success": False, "error": "Linux 桌面环境不支持自动打开，请手动打开目录"}
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.get("/api/jobs")
async def api_jobs() -> dict:
    manager: JobManager = app.state.manager
    return {"jobs": [j.to_dict() for j in manager.list_jobs()]}


@app.post("/api/jobs/{job_id}/cancel")
async def api_cancel(job_id: int) -> dict:
    manager: JobManager = app.state.manager
    ok = manager.cancel(job_id)
    if not ok:
        raise HTTPException(status_code=400, detail="只能取消尚未开始的队列任务")
    return {"id": job_id, "status": "canceled"}


@app.post("/api/jobs/{job_id}/retry")
async def api_retry_job(job_id: int) -> dict:
    manager: JobManager = app.state.manager
    job = manager.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    ok = manager.retry(job_id)
    if not ok:
        raise HTTPException(status_code=400, detail="只能重试失败或已取消的任务")
    return {"id": job_id, "status": "queued"}


@app.delete("/api/jobs/{job_id}")
async def api_delete_job(job_id: int) -> dict:
    """删除单个下载记录（同时删除服务器端文件）"""
    manager: JobManager = app.state.manager
    job = manager.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    try:
        manager.delete_job_file(job_id)
    except Exception:
        pass  # 删除文件失败不影响删除记录
    ok = manager.delete_job(job_id)
    return {"id": job_id, "status": "deleted"}


from pydantic import BaseModel
class DeleteJobsRequest(BaseModel):
    ids: list[int] | None = None  # None = 删除全部


class JobIdsRequest(BaseModel):
    ids: list[int]


@app.post("/api/jobs/delete")
async def api_delete_jobs(req: DeleteJobsRequest | None = None) -> dict:
    """批量删除下载记录（同时删除服务器端文件），ids=None 表示删除全部"""
    manager: JobManager = app.state.manager
    if req is None or req.ids is None:
        # 删除全部时同时删除所有文件
        for job in manager.list_jobs():
            try:
                manager.delete_job_file(job.id)
            except Exception:
                pass
        count = manager.delete_all_jobs()
        return {"deleted_count": count, "action": "all"}
    count = 0
    for job_id in req.ids:
        job = manager.get_job(job_id)
        if job:
            try:
                manager.delete_job_file(job.id)
            except Exception:
                pass
        if manager.delete_job(job_id):
            count += 1
    return {"deleted_count": count, "ids": req.ids}


@app.post("/api/jobs/download-zip")
async def api_download_jobs_zip(req: JobIdsRequest):
    manager: JobManager = app.state.manager
    if not req.ids:
        raise HTTPException(status_code=400, detail="请选择要下载的任务")

    jobs = []
    seen_ids: set[int] = set()
    for job_id in req.ids:
        if job_id in seen_ids:
            continue
        seen_ids.add(job_id)
        job = manager.get_job(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail=f"任务 {job_id} 不存在")
        if job.status != JobStatus.COMPLETED:
            raise HTTPException(status_code=400, detail="只能批量下载已完成的任务")
        if not job.output_path.exists():
            raise HTTPException(status_code=404, detail=f"文件不存在: {job.output_path.name}")
        jobs.append(job)

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
    tmp_path = Path(tmp.name)
    tmp.close()
    with zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        used_names: dict[str, int] = {}
        for job in jobs:
            arcname = job.output_path.name
            if arcname in used_names:
                used_names[arcname] += 1
                stem = Path(arcname).stem
                suffix = Path(arcname).suffix
                arcname = f"{stem}-{used_names[arcname]}{suffix}"
            else:
                used_names[arcname] = 1
            zf.write(job.output_path, arcname=arcname)
            manager.mark_as_exported(job.id)

    return FileResponse(
        tmp_path,
        media_type="application/zip",
        filename=f"ovd-videos-{int(time.time())}.zip",
    )


@app.get("/api/jobs/{job_id}/download")
async def api_download_job(job_id: int, delete_after: bool = True):
    """下载任务视频文件（可选下载后自动删除）"""
    manager: JobManager = app.state.manager
    job = manager.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    if job.status != JobStatus.COMPLETED:
        raise HTTPException(status_code=400, detail="只能下载已完成的任务")

    file_path = job.output_path
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="文件不存在")

    # 标记为已导出（用于 UI 显示）
    if delete_after:
        manager.mark_as_exported(job_id)

    # 先用 FileResponse 返回文件
    # 注意：文件删除需要由前端调用单独的 API
    return FileResponse(
        file_path,
        media_type="video/mp4",
        filename=file_path.name,
    )


@app.post("/api/jobs/{job_id}/delete-file")
async def api_delete_job_file(job_id: int) -> dict:
    """删除已导出任务的服务器端文件"""
    manager: JobManager = app.state.manager
    job = manager.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="任务不存在")

    file_path = job.output_path
    try:
        manager.delete_job_file(job_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"删除文件失败: {e}")

    return {"success": True, "deleted": str(file_path)}


@app.post("/api/jobs/delete-files")
async def api_delete_job_files(req: JobIdsRequest) -> dict:
    manager: JobManager = app.state.manager
    if not req.ids:
        raise HTTPException(status_code=400, detail="请选择要删除文件的任务")
    count = 0
    for job_id in req.ids:
        job = manager.get_job(job_id)
        if job is None:
            continue
        try:
            manager.delete_job_file(job_id)
            count += 1
        except Exception:
            continue
    return {"deleted_count": count, "ids": req.ids}


# --- 搜索历史 --------------------------------------------------------------

@app.get("/api/search-history")
async def api_search_history(limit: int = 20) -> dict:
    """获取搜索历史"""
    storage: LocalStorage = app.state.storage
    return {
        "items": storage.get_search_history(limit),
    }


@app.delete("/api/search-history")
async def api_clear_search_history() -> dict:
    """清空搜索历史"""
    storage: LocalStorage = app.state.storage
    storage.clear_search_history()
    return {"success": True}


@app.delete("/api/search-history/{keyword:path}")
async def api_remove_search_history(keyword: str) -> dict:
    """删除单个搜索历史"""
    storage: LocalStorage = app.state.storage
    storage.remove_search_history(keyword)
    return {"success": True, "keyword": keyword}


# --- 收藏 -------------------------------------------------------------------

@app.get("/api/favorites")
async def api_get_favorites() -> dict:
    """获取所有收藏"""
    storage: LocalStorage = app.state.storage
    return {
        "items": storage.get_favorites(),
    }


@app.post("/api/favorites")
async def api_add_favorite(data: FavoriteIn) -> dict:
    """添加收藏"""
    storage: LocalStorage = app.state.storage
    storage.add_favorite(
        source_name=data.source_name,
        vod_id=data.vod_id,
        name=data.name,
        pic=data.pic,
        remarks=data.remarks,
        year=data.year,
        area=data.area,
        type_name=data.type_name,
    )
    return {"success": True, "source_name": data.source_name, "vod_id": data.vod_id}


@app.delete("/api/favorites/{source_name}/{vod_id}")
async def api_remove_favorite(source_name: str, vod_id: int) -> dict:
    """取消收藏"""
    storage: LocalStorage = app.state.storage
    storage.remove_favorite(source_name, vod_id)
    return {"success": True, "source_name": source_name, "vod_id": vod_id}


@app.get("/api/favorites/{source_name}/{vod_id}")
async def api_check_favorite(source_name: str, vod_id: int) -> dict:
    """检查是否已收藏"""
    storage: LocalStorage = app.state.storage
    return {
        "is_favorite": storage.is_favorite(source_name, vod_id),
    }


# --- 主题设置 ---------------------------------------------------------------

@app.get("/api/settings/theme")
async def api_get_theme() -> dict:
    """获取主题设置"""
    storage: LocalStorage = app.state.storage
    return {
        "dark_mode": storage.dark_mode,
    }


@app.post("/api/settings/theme")
async def api_set_theme(dark_mode: bool) -> dict:
    """设置主题"""
    storage: LocalStorage = app.state.storage
    storage.dark_mode = dark_mode
    return {"success": True, "dark_mode": dark_mode}


class MaxJobsIn(BaseModel):
    max_jobs: int = Field(..., ge=1, le=100)


@app.get("/api/settings/max-jobs")
async def api_get_max_jobs() -> dict:
    """获取下载记录最多保留个数"""
    settings: Settings = app.state.settings
    return {"max_jobs": settings.max_jobs}


@app.post("/api/settings/max-jobs")
async def api_set_max_jobs(data: MaxJobsIn) -> dict:
    """设置下载记录最多保留个数"""
    settings: Settings = app.state.settings
    settings.save_max_jobs(data.max_jobs)
    app.state.settings = Settings.load()
    app.state.manager._settings = app.state.settings
    app.state.client = MacCMSClient(app.state.settings)
    app.state.bili_client = BiliBiliClient(app.state.settings)
    return {"success": True, "max_jobs": app.state.settings.max_jobs}


# --- Bilibili 视频下载 (独立模块，完全不影响现有功能) ------------------------

@app.get("/api/bilibili/search")
async def api_bilibili_search(wd: str, page: int = 1) -> dict:
    """搜索 Bilibili 视频"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")
    
    bili_client = getattr(app.state, 'bili_client', None) or BiliBiliClient(settings)
    items = await bili_client.search(wd, page=page)
    
    # 记录搜索历史
    if wd.strip():
        storage = getattr(app.state, 'storage', None)
        if storage:
            storage.add_search_history(wd)
    
    return {
        "keyword": wd,
        "count": len(items),
        "items": [
            {
                "bvid": v.bvid,
                "title": v.title,
                "pic": v.pic,
                "uploader": v.uploader,
                "duration": v.duration,
                "view_count": v.view_count,
                "pubdate": v.pubdate,
            }
            for v in items
        ],
    }

@app.get("/api/bilibili/settings")
async def api_bilibili_get_settings() -> dict:
    """获取 Bilibili 配置"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    return {
        "enabled": settings.bilibili_enabled,
        "has_cookies": bool(settings.bilibili_cookies and len(settings.bilibili_cookies) > 0),
    }


class BilibiliSettingsIn(BaseModel):
    enabled: bool
    cookies: str = ""


@app.post("/api/bilibili/settings")
async def api_bilibili_set_settings(data: BilibiliSettingsIn) -> dict:
    """设置 Bilibili 配置"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    cookies = settings.bilibili_cookies if data.cookies == "******" else data.cookies
    settings.save_bilibili_settings(data.enabled, cookies)
    # 重新加载配置并更新客户端/下载器
    new_settings = Settings.load_from_dir(settings.download_dir)
    app.state.settings = new_settings
    app.state.bili_client = BiliBiliClient(new_settings)
    if hasattr(app.state, 'manager'):
        app.state.manager._settings = new_settings
    return {
        "success": True,
        "enabled": data.enabled,
        "has_cookies": bool(data.cookies),
    }




# 内存存储当前登录会话
_bilibili_login_sessions = {}

@app.get("/api/bilibili/login/qrcode")
async def api_bilibili_get_qrcode() -> dict:
    """获取 Bilibili 登录二维码"""
    import uuid
    session_id = str(uuid.uuid4())
    
    from ovd.api.bilibili_login import BiliBiliLogin
    login = BiliBiliLogin()
    result = await login.get_qrcode()
    
    if not result.success:
        raise HTTPException(status_code=500, detail=result.message)
    
    # 保存会话
    _bilibili_login_sessions[session_id] = {
        'login': login,
        'qrcode_key': result.qrcode_key,
        'created_at': __import__('time').time(),
    }
    
    return {
        'session_id': session_id,
        'qrcode_url': result.qrcode_url,
        'login_url': result.login_url,
        'qrcode_key': result.qrcode_key,
    }

@app.get("/api/bilibili/login/qrcode-image")
async def api_bilibili_qrcode_image(url: str = "") -> Response:
    """代理获取二维码图片，前端可直接用 <img> 显示。"""
    import httpx
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url)
            return Response(content=resp.content, media_type=resp.headers.get("content-type", "image/png"))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"获取二维码图片失败: {e}")


@app.get("/api/bilibili/login/check/{session_id}")
async def api_bilibili_check_login(session_id: str) -> dict:
    """检查 Bilibili 扫码登录状态"""
    session = _bilibili_login_sessions.get(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="会话不存在，请重新获取二维码")
    
    login = session['login']
    result = await login.check_login(session['qrcode_key'])
    
    if result.success and result.cookies:
        verified = await login.verify_cookies(result.cookies)
        if not verified:
            del _bilibili_login_sessions[session_id]
            return {
                'success': False,
                'message': '登录成功但 Cookies 校验失败，请重新扫码',
                'has_cookies': False,
            }

        settings = getattr(app.state, 'settings', None) or Settings.load()
        settings.save_bilibili_settings(enabled=True, cookies=result.cookies)
        new_settings = Settings.load_from_dir(settings.download_dir)
        app.state.settings = new_settings
        app.state.bili_client = BiliBiliClient(new_settings)
        if hasattr(app.state, 'manager'):
            app.state.manager._settings = new_settings
        del _bilibili_login_sessions[session_id]

        return {
            'success': True,
            'message': '登录成功，Cookies 已保存成功',
            'has_cookies': True,
        }
    else:
        return {
            'success': False,
            'message': result.message,
        }

@app.get("/api/bilibili/search")
async def api_bilibili_search(wd: str, page: int = 1) -> dict:
    """搜索 Bilibili 视频"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")
    
    bili_client = getattr(app.state, 'bili_client', None) or BiliBiliClient(settings)
    items = await bili_client.search(wd, page=page)
    
    # 记录搜索历史
    if wd.strip():
        storage = getattr(app.state, 'storage', None)
        if storage:
            storage.add_search_history(wd)
    
    return {
        "keyword": wd,
        "count": len(items),
        "items": [
            {
                "bvid": v.bvid,
                "title": v.title,
                "pic": v.pic,
                "uploader": v.uploader,
                "duration": v.duration,
                "view_count": v.view_count,
                "pubdate": v.pubdate,
            }
            for v in items
        ],
    }


@app.get("/api/bilibili/detail/{bvid}")
async def api_bilibili_detail(bvid: str) -> dict:
    """获取 Bilibili 视频详情和分P列表"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")
    
    bili_client = getattr(app.state, 'bili_client', None) or BiliBiliClient(settings)
    detail = await bili_client.detail(bvid)
    if detail is None:
        if not settings.bilibili_cookies:
            raise HTTPException(
                status_code=403,
                detail="Bilibili 反爬限制，请在设置中配置浏览器 Cookies。方法：浏览器登录 Bilibili → F12 → Network → 复制 Cookie 粘贴到设置页"
            )
        raise HTTPException(status_code=404, detail="无法获取视频信息，请检查网络或更新 Cookies")
    
    return {
        "bvid": detail.bvid,
        "title": detail.title,
        "pic": detail.pic,
        "desc": detail.desc,
        "uploader": detail.uploader,
        "duration": detail.duration,
        "view_count": detail.view_count,
        "pub_date": detail.pub_date,
        "episodes": [
            {
                "page": e.page,
                "name": e.name,
                "cid": e.cid,
                "bvid": e.bvid,
                "url": f"https://www.bilibili.com/video/{e.bvid}?p={e.page}",
            }
            for e in detail.episodes
        ],
        "formats": [
            {
                "format_id": f.format_id,
                "ext": f.ext,
                "quality": f.quality,
                "width": f.width,
                "height": f.height,
                "has_video": f.has_video,
                "has_audio": f.has_audio,
            }
            for f in detail.formats
        ],
    }


class BilibiliDownloadIn(BaseModel):
    bvid: str
    title: str
    episodes: list[int]  # 要下载的分P页码列表
    format_id: str | None = None  # 指定画质，None 表示自动选择最佳


class BilibiliUploaderVideoIn(BaseModel):
    bvid: str
    title: str


class BilibiliUploaderDownloadIn(BaseModel):
    videos: list[BilibiliUploaderVideoIn] = Field(..., min_length=1)
    uploader_name: str = ""
    format_id: str | None = None


@app.get("/api/bilibili/uploaders/search")
async def api_bilibili_search_uploaders(wd: str, page: int = 1) -> dict:
    """按名称搜索 Bilibili UP 主"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")

    bili_client = getattr(app.state, 'bili_client', None) or BiliBiliClient(settings)
    items = await bili_client.search_uploaders(wd, page=page)
    return {
        "keyword": wd,
        "count": len(items),
        "items": [
            {
                "mid": u.mid,
                "name": u.name,
                "face": u.face,
                "fans": u.fans,
                "sign": u.sign,
            }
            for u in items
        ],
    }


@app.get("/api/bilibili/uploaders/{mid}/videos")
async def api_bilibili_uploader_videos(mid: int, page: int = 1, name: str = "", all: bool = False) -> dict:
    """获取 UP 主投稿视频"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")

    bili_client = getattr(app.state, 'bili_client', None) or BiliBiliClient(settings)
    if all:
        items = await bili_client.list_all_uploader_videos(mid, uploader_name=name)
    else:
        items = await bili_client.list_uploader_videos(mid, page=page, uploader_name=name)
    return {
        "mid": mid,
        "page": page,
        "count": len(items),
        "items": [
            {
                "bvid": v.bvid,
                "title": v.title,
                "pic": v.pic,
                "duration": v.duration,
                "view_count": v.view_count,
                "pubdate": v.pubdate,
            }
            for v in items
        ],
    }


@app.post("/api/bilibili/uploaders/download")
async def api_bilibili_download_uploader_videos(payload: BilibiliUploaderDownloadIn) -> dict:
    """批量下载 UP 主投稿视频"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")

    manager: JobManager = app.state.manager
    current_jobs = manager.list_jobs()
    if len(current_jobs) + len(payload.videos) > settings.max_jobs:
        raise HTTPException(
            status_code=400,
            detail=f"下载记录最多同时保留{settings.max_jobs}条，请先删除已下载的记录"
        )

    jobs = []
    default_format = BILIBILI_DEFAULT_FORMAT
    folder_name = payload.uploader_name or "Bilibili"
    for video in payload.videos:
        url = f"https://www.bilibili.com/video/{video.bvid}?format={payload.format_id or default_format}"
        job = manager.enqueue(
            video_name=video.title,
            episode_name=video.title,
            url=url,
            folder_name=folder_name,
        )
        jobs.append(job)

    return {"queued": len(jobs), "jobs": [j.to_dict() for j in jobs]}


@app.post("/api/bilibili/download")
async def api_bilibili_download(payload: BilibiliDownloadIn) -> dict:
    """下载 Bilibili 视频（支持批量分P下载）"""
    settings = getattr(app.state, 'settings', None) or Settings.load()
    if not settings.bilibili_enabled:
        raise HTTPException(status_code=403, detail="Bilibili 功能未启用，请在设置中开启")
    
    manager: JobManager = app.state.manager

    current_jobs = manager.list_jobs()
    if len(current_jobs) + len(payload.episodes) > settings.max_jobs:
        raise HTTPException(
            status_code=400,
            detail=f"下载记录最多同时保留{settings.max_jobs}条，请先删除已下载的记录"
        )
    
    jobs = []
    default_format = BILIBILI_DEFAULT_FORMAT
    for page in payload.episodes:
        url = f"https://www.bilibili.com/video/{payload.bvid}?p={page}&format={payload.format_id or default_format}"

        job = manager.enqueue(
            video_name=f"[Bilibili] {payload.title}",
            episode_name=f"第{page}P",
            url=url,
        )
        jobs.append(job)
    
    return {"queued": len(jobs), "jobs": [j.to_dict() for j in jobs]}


# --- 搜索源管理 -------------------------------------------------------------

@app.get("/api/sources")
async def api_get_sources() -> dict:
    """获取所有搜索源"""
    settings: Settings = app.state.settings
    return {
        "sources": [s.to_dict() for s in settings.sources],
    }


@app.post("/api/sources")
async def api_add_source(source: SourceIn) -> dict:
    """新增搜索源"""
    settings: Settings = app.state.settings
    sources = list(settings.sources)
    # 检查名称是否已存在
    for s in sources:
        if s.name == source.name:
            raise HTTPException(status_code=400, detail=f"源名称 '{source.name}' 已存在")
    sources.append(Source(name=source.name, api=source.api))
    settings.save_sources(sources)
    # 保存后需要更新 app.state.settings
    app.state.settings = Settings.load()
    # 同时需要更新 client 使用新的源列表
    app.state.client = MacCMSClient(app.state.settings)
    return {"success": True, "source": {"name": source.name, "api": source.api}}


@app.put("/api/sources")
async def api_update_source(data: SourceUpdateIn) -> dict:
    """修改搜索源"""
    settings: Settings = app.state.settings
    sources = list(settings.sources)
    # 查找并更新
    found = False
    for i, s in enumerate(sources):
        if s.name == data.old_name:
            # 检查新名称是否与其他源冲突
            if data.new_name != data.old_name:
                for j, s2 in enumerate(sources):
                    if j != i and s2.name == data.new_name:
                        raise HTTPException(status_code=400, detail=f"源名称 '{data.new_name}' 已存在")
            sources[i] = Source(name=data.new_name, api=data.new_api)
            found = True
            break
    if not found:
        raise HTTPException(status_code=404, detail=f"源 '{data.old_name}' 不存在")
    settings.save_sources(sources)
    app.state.settings = Settings.load()
    app.state.client = MacCMSClient(app.state.settings)
    return {"success": True, "source": {"name": data.new_name, "api": data.new_api}}


@app.delete("/api/sources/{name}")
async def api_delete_source(name: str) -> dict:
    """删除搜索源"""
    settings: Settings = app.state.settings
    sources = list(settings.sources)
    # 至少保留一个源
    if len(sources) <= 1:
        raise HTTPException(status_code=400, detail="至少需要保留一个搜索源")
    # 查找并删除
    for i, s in enumerate(sources):
        if s.name == name:
            del sources[i]
            settings.save_sources(sources)
            app.state.settings = Settings.load()
            app.state.client = MacCMSClient(app.state.settings)
            return {"success": True, "deleted": name}
    raise HTTPException(status_code=404, detail=f"源 '{name}' 不存在")
