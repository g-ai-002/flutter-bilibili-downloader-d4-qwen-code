# -*- mode: python ; coding: utf-8 -*-

datas = [('ovd/static', 'ovd/static')]
binaries = []
hiddenimports = [
    'uvicorn', 'uvicorn.logging', 'uvicorn.loops.auto', 'uvicorn.protocols.http.auto',
    'uvicorn.protocols.websockets', 'uvicorn.protocols.http', 'uvicorn.loops',
    'fastapi', 'pydantic', 'pydantic.main', 'pydantic.fields',
    'starlette', 'starlette.applications', 'starlette.routing', 'starlette.middleware',
    'httpx', 'anyio', 'sniffio',
    'cryptography', 'cryptography.hazmat.primitives',
    'PIL', 'PIL.Image', 'yt_dlp', 'yt_dlp.extractor',
]

a = Analysis(
    ['ovd/__main__.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='ovd',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)