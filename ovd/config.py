"""配置加载: 数据源列表、下载目录、并发数。"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Source:
    """单个 MacCMS V10 采集站。"""

    name: str
    api: str  # 形如 https://example.com/api.php/provide/vod

    def to_dict(self) -> dict:
        return {"name": self.name, "api": self.api}

    @classmethod
    def from_dict(cls, d: dict) -> "Source":
        return cls(name=d["name"], api=d["api"])


# 默认数据源 (MacCMS V10 标准接口, 与 7080.wang 同类资源)
# 按稳定性排序，推荐优先使用靠前的源
DEFAULT_SOURCES: tuple[Source, ...] = (
    Source(name="光速资源", api="https://api.guangsuapi.com/api.php/provide/vod"),
    Source(name="量子资源", api="https://cj.lziapi.com/api.php/provide/vod"),
    Source(name="暴风云资源", api="https://bfzyapi.com/api.php/provide/vod"),
    Source(name="非凡资源", api="https://cj.ffzyapi.com/api.php/provide/vod"),
    Source(name="金鹰资源", api="https://jyzyapi.com/api.php/provide/vod"),
)


@dataclass(frozen=True)
class Settings:
    download_dir: Path
    sources: tuple[Source, ...] = field(default_factory=lambda: DEFAULT_SOURCES)
    concurrency: int = 1  # 同时下载集数 (每集内部 12 并发拉 TS)
    request_timeout: float = 15.0
    user_agent: str = (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )
    # Bilibili 支持开关（默认开启）
    bilibili_enabled: bool = True
    # Bilibili cookies 文件路径（可选，用于绕过反爬）
    bilibili_cookies: str = ""
    # 下载记录最多保留个数
    max_jobs: int = 10

    @property
    def _config_file(self) -> Path:
        """配置文件路径。"""
        return self.download_dir / ".ovd_config.json"

    def save_sources(self, sources: list[Source]) -> None:
        """保存自定义搜索源。"""
        try:
            # 读取现有配置（保留 Bilibili 设置）
            existing = self._load_all()
            existing["sources"] = [s.to_dict() for s in sources]
            with open(self._config_file, "w", encoding="utf-8") as f:
                json.dump(existing, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def _load_custom_sources(self) -> tuple[Source, ...]:
        """加载自定义搜索源。"""
        data = self._load_all()
        if "sources" in data and isinstance(data["sources"], list):
            return tuple(Source.from_dict(s) for s in data["sources"])
        return DEFAULT_SOURCES

    def _load_all(self) -> dict:
        """加载所有配置。"""
        try:
            if self._config_file.exists():
                with open(self._config_file, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return {}

    def save_bilibili_settings(self, enabled: bool, cookies: str = "") -> None:
        """保存 Bilibili 配置。"""
        try:
            data = self._load_all()
            data["bilibili_enabled"] = enabled
            data["bilibili_cookies"] = cookies
            with open(self._config_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def save_max_jobs(self, max_jobs: int) -> None:
        """保存下载记录最多保留个数。"""
        try:
            data = self._load_all()
            data["max_jobs"] = max(1, int(max_jobs))
            with open(self._config_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    @classmethod
    def load_from_dir(cls, download_dir: Path) -> "Settings":
        download_dir.mkdir(parents=True, exist_ok=True)
        temp_settings = cls(download_dir=download_dir)
        sources = temp_settings._load_custom_sources()
        config_data = temp_settings._load_all()
        bilibili_enabled = config_data.get("bilibili_enabled", False)
        bilibili_cookies = config_data.get("bilibili_cookies", "")
        max_jobs = int(config_data.get("max_jobs", 10))

        return cls(
            download_dir=download_dir,
            sources=sources,
            concurrency=max(1, int(os.environ.get("OVD_CONCURRENCY", "1"))),
            bilibili_enabled=bilibili_enabled,
            bilibili_cookies=bilibili_cookies,
            max_jobs=max(1, max_jobs),
        )

    @classmethod
    def load(cls) -> "Settings":
        download_dir = Path(
            os.environ.get("OVD_DOWNLOAD_DIR", "./downloads")
        ).expanduser().resolve()
        return cls.load_from_dir(download_dir)
