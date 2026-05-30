"""ovd.web 子包: FastAPI 应用。"""

# PyInstaller 兼容：优先尝试绝对导入
try:
    from ovd.web.app import app
except ImportError:
    from .app import app

__all__ = ["app"]
