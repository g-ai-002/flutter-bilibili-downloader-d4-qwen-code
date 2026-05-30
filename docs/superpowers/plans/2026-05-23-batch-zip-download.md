# Batch ZIP Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a button that downloads selected completed server-side videos to the user's local machine as one ZIP file.

**Architecture:** Reuse the existing job list selection UI and completed-job download semantics. Add a FastAPI endpoint that validates selected completed jobs, streams a temporary ZIP containing their merged video files, and marks them exported. Add a second batch file-deletion endpoint so the frontend can delete server-side source files after the browser download is triggered, matching the existing single-download behavior.

**Tech Stack:** Python 3.12, FastAPI `FileResponse`, standard-library `zipfile`/`tempfile`, pytest/FastAPI TestClient, vanilla JavaScript in `ovd/static/index.html`.

---

## File Structure

- Modify `ovd/web/app.py`: add request model for batch IDs, ZIP creation endpoint, and batch delete-files endpoint.
- Modify `ovd/static/index.html`: add selected-download buttons, enable/disable logic, `downloadSelectedJobs()` function, and global export.
- Modify `tests/test_bilibili.py`: add route tests for ZIP download and batch delete-files behavior.

---

### Task 1: Add backend ZIP download endpoint

**Files:**
- Modify: `ovd/web/app.py:436-477`
- Test: `tests/test_bilibili.py`

- [ ] **Step 1: Write failing ZIP endpoint tests**

Append these tests near the existing retry/download API tests in `tests/test_bilibili.py`:

```python
def test_download_jobs_zip_returns_selected_completed_files(tmp_path):
    import io
    import zipfile

    from fastapi.testclient import TestClient
    from ovd.config import Settings
    from ovd.downloader.jobs import JobManager, JobStatus
    from ovd.web.app import app

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


def test_download_jobs_zip_rejects_unfinished_or_missing_files(tmp_path):
    from fastapi.testclient import TestClient
    from ovd.config import Settings
    from ovd.downloader.jobs import JobManager, JobStatus
    from ovd.web.app import app

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_bilibili.py::test_download_jobs_zip_returns_selected_completed_files tests/test_bilibili.py::test_download_jobs_zip_rejects_unfinished_or_missing_files -v
```

Expected: both tests fail with 404 because `/api/jobs/download-zip` does not exist.

- [ ] **Step 3: Implement the ZIP endpoint**

In `ovd/web/app.py`, add imports near the existing imports if they are missing:

```python
import tempfile
import zipfile
from pathlib import Path
```

Add this request model near `DeleteJobsRequest`:

```python
class JobIdsRequest(BaseModel):
    ids: list[int]
```

Add this endpoint after `api_download_job()` and before `api_delete_job_file()`:

```python
@app.post("/api/jobs/download-zip")
async def api_download_jobs_zip(req: JobIdsRequest):
    manager: JobManager = app.state.manager
    if not req.ids:
        raise HTTPException(status_code=400, detail="请选择要下载的任务")

    jobs = []
    for job_id in req.ids:
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
```

- [ ] **Step 4: Run ZIP endpoint tests**

Run:

```bash
pytest tests/test_bilibili.py::test_download_jobs_zip_returns_selected_completed_files tests/test_bilibili.py::test_download_jobs_zip_rejects_unfinished_or_missing_files -v
```

Expected: PASS.

- [ ] **Step 5: Run route-adjacent tests**

Run:

```bash
pytest tests/test_bilibili.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit task 1**

```bash
git add ovd/web/app.py tests/test_bilibili.py
git commit -m "feat(api): 添加批量视频打包下载接口"
```

---

### Task 2: Add backend batch delete-files endpoint

**Files:**
- Modify: `ovd/web/app.py:463-477`
- Test: `tests/test_bilibili.py`

- [ ] **Step 1: Write failing batch delete-files test**

Append this test near the ZIP endpoint tests in `tests/test_bilibili.py`:

```python
def test_delete_job_files_endpoint_removes_selected_files(tmp_path):
    from fastapi.testclient import TestClient
    from ovd.config import Settings
    from ovd.downloader.jobs import JobManager, JobStatus
    from ovd.web.app import app

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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
pytest tests/test_bilibili.py::test_delete_job_files_endpoint_removes_selected_files -v
```

Expected: FAIL with 404 because `/api/jobs/delete-files` does not exist.

- [ ] **Step 3: Implement batch delete-files endpoint**

In `ovd/web/app.py`, add this endpoint after `api_delete_job_file()`:

```python
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
```

- [ ] **Step 4: Run batch delete-files test**

Run:

```bash
pytest tests/test_bilibili.py::test_delete_job_files_endpoint_removes_selected_files -v
```

Expected: PASS.

- [ ] **Step 5: Run route-adjacent tests**

Run:

```bash
pytest tests/test_bilibili.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit task 2**

```bash
git add ovd/web/app.py tests/test_bilibili.py
git commit -m "feat(api): 支持批量删除已导出视频文件"
```

---

### Task 3: Add frontend selected ZIP download button

**Files:**
- Modify: `ovd/static/index.html:774-914`
- Modify: `ovd/static/index.html:1440-1498`
- Modify: `ovd/static/index.html:1588-1608`

- [ ] **Step 1: Add selected download buttons to existing job toolbar**

Search for the existing buttons with IDs `btnDeleteSelected` and `btnDeleteSelectedDetail` in `ovd/static/index.html`. Add a `下载选中` button next to each delete-selected button:

```html
<button id="btnDownloadSelected" class="btn btn-sm btn-success" disabled>下载选中</button>
```

and in the detail toolbar:

```html
<button id="btnDownloadSelectedDetail" class="btn btn-sm btn-success" disabled>下载选中</button>
```

- [ ] **Step 2: Enable selected download buttons with selected-job state**

In `updateDeleteButtons()`, replace:

```js
    const btnList = ['#btnDeleteSelected', '#btnDeleteSelectedDetail'];
    btnList.forEach(sel => {
      const btn = $(sel);
      if (btn) btn.disabled = disabled;
    });
```

with:

```js
    const btnList = ['#btnDeleteSelected', '#btnDeleteSelectedDetail', '#btnDownloadSelected', '#btnDownloadSelectedDetail'];
    btnList.forEach(sel => {
      const btn = $(sel);
      if (btn) btn.disabled = disabled;
    });
```

- [ ] **Step 3: Add `downloadSelectedJobs()` function**

Add this function after `downloadJob()` and before `retryJob()`:

```js
  async function downloadSelectedJobs() {
    const checked = document.querySelectorAll('.job-checkbox:checked');
    if (checked.length === 0) return;
    const ids = Array.from(checked).map(cb => parseInt(cb.dataset.id));
    if (!confirm(`确定要打包下载选中的 ${ids.length} 个已完成视频吗？下载触发后会自动删除服务器端源文件。`)) return;

    const response = await fetch('/api/jobs/download-zip', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ids }),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || '批量下载失败');
    }
    const blob = await response.blob();
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ovd-videos-${Date.now()}.zip`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    setTimeout(async () => {
      try {
        await api('/api/jobs/delete-files', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ids }),
        });
      } catch (e) {
        console.log('Delete selected server files failed:', e);
      }
      selectedJobIds.clear();
      refreshJobs();
    }, 3000);
  }
```

- [ ] **Step 4: Bind selected download buttons**

Near the existing button event bindings, add:

```js
  $('#btnDownloadSelected').onclick = downloadSelectedJobs;
  $('#btnDownloadSelectedDetail').onclick = downloadSelectedJobs;
```

- [ ] **Step 5: Export function on `window`**

Near the existing `window.downloadJob = downloadJob;` exports at the bottom of `ovd/static/index.html`, add:

```js
  window.downloadSelectedJobs = downloadSelectedJobs;
```

- [ ] **Step 6: Run frontend syntax check**

Run:

```bash
python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

class ScriptExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_script = False
        self.scripts = []
    def handle_starttag(self, tag, attrs):
        if tag == 'script' and not dict(attrs).get('src'):
            self.in_script = True
            self.scripts.append('')
    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_script = False
    def handle_data(self, data):
        if self.in_script:
            self.scripts[-1] += data

parser = ScriptExtractor()
parser.feed(Path('ovd/static/index.html').read_text(encoding='utf-8'))
Path('/tmp/ovd-index-inline.js').write_text('\n'.join(parser.scripts), encoding='utf-8')
PY
node --check /tmp/ovd-index-inline.js
```

Expected: exit code 0 with no syntax errors.

- [ ] **Step 7: Commit task 3**

```bash
git add ovd/static/index.html
git commit -m "feat(ui): 添加选中视频打包下载按钮"
```

---

### Task 4: Final verification and deployment

**Files:**
- Verify: `ovd/web/app.py`
- Verify: `ovd/static/index.html`
- Verify: `tests/test_bilibili.py`

- [ ] **Step 1: Run full test suite**

Run:

```bash
pytest -v
```

Expected: all tests pass.

- [ ] **Step 2: Run frontend syntax check**

Run:

```bash
python3 - <<'PY'
from html.parser import HTMLParser
from pathlib import Path

class ScriptExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_script = False
        self.scripts = []
    def handle_starttag(self, tag, attrs):
        if tag == 'script' and not dict(attrs).get('src'):
            self.in_script = True
            self.scripts.append('')
    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_script = False
    def handle_data(self, data):
        if self.in_script:
            self.scripts[-1] += data

parser = ScriptExtractor()
parser.feed(Path('ovd/static/index.html').read_text(encoding='utf-8'))
Path('/tmp/ovd-index-inline.js').write_text('\n'.join(parser.scripts), encoding='utf-8')
PY
node --check /tmp/ovd-index-inline.js
```

Expected: exit code 0 with no syntax errors.

- [ ] **Step 3: Restart or verify reload deployment**

Run:

```bash
pgrep -af "uvicorn.*ovd.web.app:app"
```

If the service is running with `--reload`, confirm logs show reload after `ovd/web/app.py` or `ovd/static/index.html` changes. If it is not running, start it:

```bash
python3 -m uvicorn ovd.web.app:app --host 0.0.0.0 --port 8787 --reload
```

Then run:

```bash
python3 - <<'PY'
import json
import urllib.request
with urllib.request.urlopen('http://127.0.0.1:8787/api/jobs', timeout=10) as resp:
    data = json.loads(resp.read().decode())
print('jobs', len(data.get('jobs', [])))
PY
```

Expected: `/api/jobs` returns successfully.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected: only intended implementation files are modified, plus known local untracked files such as `.claude/` and `ovd.exe`.

- [ ] **Step 5: Commit final verification fix if needed**

If Step 1 or Step 2 reveals a real implementation issue and a code fix is made, commit only the fixed files:

```bash
git add ovd/web/app.py ovd/static/index.html tests/test_bilibili.py
git commit -m "fix(ui): 修复批量下载验证问题"
```

If no fix is needed, do not create an empty commit.

---

## Self-Review Notes

- Spec coverage: ZIP batch download, validation of completed tasks, marking exported, follow-up server file deletion, selected-job UI button, and deployment verification are all mapped to tasks.
- Placeholder scan: this plan contains no TBD/TODO placeholders and includes concrete tests, code, commands, and expected outcomes.
- Type consistency: the request model is consistently `JobIdsRequest`; endpoints are consistently `POST /api/jobs/download-zip` and `POST /api/jobs/delete-files`; frontend function is consistently `downloadSelectedJobs()`.
