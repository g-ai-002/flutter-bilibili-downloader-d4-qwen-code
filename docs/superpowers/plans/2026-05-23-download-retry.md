# Download Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic retry up to 3 times for transient download failures, plus a manual retry button/API for failed or canceled jobs.

**Architecture:** Extend `DownloadJob` with retry metadata persisted through `.ovd_jobs.json`. Keep retry orchestration inside `JobManager` so both m3u8 and Bilibili downloads share the same behavior. Expose a small FastAPI retry endpoint and add a front-end button in the existing job list renderer.

**Tech Stack:** Python 3.12, FastAPI, pytest/pytest-asyncio, vanilla JavaScript in `ovd/static/index.html`.

---

## File Structure

- Modify `ovd/downloader/jobs.py`: add retry fields, reset helper behavior, automatic retry scheduling, and `JobManager.retry()`.
- Modify `ovd/web/app.py`: add `POST /api/jobs/{job_id}/retry`.
- Modify `ovd/static/index.html`: show retry counts, add retry button, add `retryJob()` and export it on `window`.
- Modify `tests/test_jobs.py`: cover retry persistence, automatic retry success, retry exhaustion, and manual retry validation.
- Modify `tests/test_bilibili.py`: cover the retry API route.

---

### Task 1: Persist retry metadata on jobs

**Files:**
- Modify: `ovd/downloader/jobs.py:102-167`
- Test: `tests/test_jobs.py`

- [ ] **Step 1: Write the failing persistence test**

Append this test near the existing job persistence tests in `tests/test_jobs.py`:

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
pytest tests/test_jobs.py::test_retry_metadata_persists -v
```

Expected: FAIL with an `AttributeError` for `retry_count` or a missing key assertion because retry metadata is not implemented.

- [ ] **Step 3: Add retry fields to `DownloadJob`**

In `ovd/downloader/jobs.py`, update the `DownloadJob` dataclass fields after `exported`:

```python
    exported: bool = False
    retry_count: int = 0
    max_retries: int = 3
```

Update `to_dict()` to include these keys after `exported`:

```python
            "exported": self.exported,
            "retry_count": self.retry_count,
            "max_retries": self.max_retries,
```

Update `from_dict()` to pass these fields after `exported`:

```python
            exported=d.get("exported", False),
            retry_count=d.get("retry_count", 0),
            max_retries=d.get("max_retries", 3),
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
pytest tests/test_jobs.py::test_retry_metadata_persists -v
```

Expected: PASS.

- [ ] **Step 5: Commit task 1**

```bash
git add ovd/downloader/jobs.py tests/test_jobs.py
git commit -m "feat(downloader): 持久化任务重试状态"
```

---

### Task 2: Automatically retry transient failures up to 3 times

**Files:**
- Modify: `ovd/downloader/jobs.py:374-403`
- Test: `tests/test_jobs.py`

- [ ] **Step 1: Write failing automatic retry tests**

Append these tests to `tests/test_jobs.py` after the existing `_run_one` tests:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_jobs.py::test_run_one_retries_transient_failure_until_success tests/test_jobs.py::test_run_one_fails_after_retry_limit -v
```

Expected: both tests FAIL because `_run_one()` immediately marks transient exceptions as `failed`.

- [ ] **Step 3: Add progress reset helper and automatic retry scheduling**

In `ovd/downloader/jobs.py`, add this method inside `JobManager` before `_run_one()`:

```python
    def _reset_job_progress(self, job: DownloadJob) -> None:
        job.total_chunks = 0
        job.downloaded_chunks = 0
        job.bytes_downloaded = 0
        job.download_speed = 0.0
        job._bytes_last_check = 0
        job._last_update_time = 0.0
        job._speed_window.clear()
```

In `_run_one()`, replace the current generic exception block:

```python
        except Exception as exc:  # noqa: BLE001
            job.status = JobStatus.FAILED
            job.error = repr(exc)
```

with:

```python
        except Exception as exc:  # noqa: BLE001
            job.error = repr(exc)
            if job.retry_count < job.max_retries:
                job.retry_count += 1
                job.status = JobStatus.QUEUED
                job.started_at = None
                job.finished_at = None
                self._reset_job_progress(job)
                self._queue.put_nowait(job)
            else:
                job.status = JobStatus.FAILED
```

Also clear stale errors after a successful download. Add this line immediately before `job.status = JobStatus.COMPLETED` in the normal success path:

```python
            job.error = None
```

Add the same line before the early completed return for existing output files:

```python
            job.error = None
```

- [ ] **Step 4: Run automatic retry tests**

Run:

```bash
pytest tests/test_jobs.py::test_run_one_retries_transient_failure_until_success tests/test_jobs.py::test_run_one_fails_after_retry_limit -v
```

Expected: PASS.

- [ ] **Step 5: Run related job tests**

Run:

```bash
pytest tests/test_jobs.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit task 2**

```bash
git add ovd/downloader/jobs.py tests/test_jobs.py
git commit -m "feat(downloader): 自动重试临时下载失败"
```

---

### Task 3: Add manual retry in `JobManager`

**Files:**
- Modify: `ovd/downloader/jobs.py:269-311`
- Test: `tests/test_jobs.py`

- [ ] **Step 1: Write failing manual retry tests**

Append these tests to `tests/test_jobs.py` near the cancel/delete job tests:

```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_jobs.py::test_retry_failed_job_requeues_and_resets_state tests/test_jobs.py::test_retry_canceled_job_requeues tests/test_jobs.py::test_retry_rejects_completed_and_downloading_jobs -v
```

Expected: FAIL with `AttributeError: 'JobManager' object has no attribute 'retry'`.

- [ ] **Step 3: Implement `JobManager.retry()`**

In `ovd/downloader/jobs.py`, add this method after `cancel()` and before `delete_job()`:

```python
    def retry(self, job_id: int) -> bool:
        job = self._jobs.get(job_id)
        if job is None or job.status not in (JobStatus.FAILED, JobStatus.CANCELED):
            return False
        job.status = JobStatus.QUEUED
        job.error = None
        job.retry_count = 0
        job.started_at = None
        job.finished_at = None
        self._reset_job_progress(job)
        self._queue.put_nowait(job)
        self.save_jobs()
        return True
```

- [ ] **Step 4: Run manual retry tests**

Run:

```bash
pytest tests/test_jobs.py::test_retry_failed_job_requeues_and_resets_state tests/test_jobs.py::test_retry_canceled_job_requeues tests/test_jobs.py::test_retry_rejects_completed_and_downloading_jobs -v
```

Expected: PASS.

- [ ] **Step 5: Run full job tests**

Run:

```bash
pytest tests/test_jobs.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit task 3**

```bash
git add ovd/downloader/jobs.py tests/test_jobs.py
git commit -m "feat(downloader): 支持手动重试失败任务"
```

---

### Task 4: Add retry API endpoint

**Files:**
- Modify: `ovd/web/app.py:363-375`
- Test: `tests/test_bilibili.py`

- [ ] **Step 1: Write failing API route test**

Append this test to `tests/test_bilibili.py` near the existing web API tests:

```python
def test_retry_job_endpoint_requeues_failed_job(tmp_path, monkeypatch):
    from fastapi.testclient import TestClient
    from ovd.config import Settings
    from ovd.downloader.jobs import JobManager, JobStatus
    from ovd.web.app import app

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
    from fastapi.testclient import TestClient
    from ovd.config import Settings
    from ovd.downloader.jobs import JobManager, JobStatus
    from ovd.web.app import app

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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_bilibili.py::test_retry_job_endpoint_requeues_failed_job tests/test_bilibili.py::test_retry_job_endpoint_rejects_completed_job -v
```

Expected: FAIL with 404 because `/api/jobs/{job_id}/retry` does not exist.

- [ ] **Step 3: Implement retry API route**

In `ovd/web/app.py`, add this route after `api_cancel()` and before `api_delete_job()`:

```python
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
```

- [ ] **Step 4: Run API route tests**

Run:

```bash
pytest tests/test_bilibili.py::test_retry_job_endpoint_requeues_failed_job tests/test_bilibili.py::test_retry_job_endpoint_rejects_completed_job -v
```

Expected: PASS.

- [ ] **Step 5: Run route-adjacent tests**

Run:

```bash
pytest tests/test_bilibili.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit task 4**

```bash
git add ovd/web/app.py tests/test_bilibili.py
git commit -m "feat(api): 添加下载任务重试接口"
```

---

### Task 5: Add retry display and retry button to the frontend

**Files:**
- Modify: `ovd/static/index.html:790-902`
- Modify: `ovd/static/index.html:1421-1447`
- Modify: `ovd/static/index.html:1590-1605`

- [ ] **Step 1: Update job progress display**

In `ovd/static/index.html`, inside `refreshJobs()`, add this line after `const cls = ...`:

```js
      const retryText = j.max_retries ? `${j.retry_count || 0}/${j.max_retries}` : `${j.retry_count || 0}`;
```

Inside the `downloading` branch, add this line before `progressHtml =`:

```js
        const retryBadge = (j.retry_count || 0) > 0 ? `<span class="badge bg-warning text-dark ms-2">第 ${j.retry_count} 次重试</span>` : '';
```

Then change the first line of the downloading progress block from:

```js
              <span class="fw-bold text-primary">📥 下载进度: ${Math.min(j.progress, 100)}%</span>
```

to:

```js
              <span class="fw-bold text-primary">下载进度: ${Math.min(j.progress, 100)}%</span>${retryBadge}
```

After the existing `completed` branch, add a failed branch:

```js
      } else if (j.status === 'failed') {
        progressHtml = `
          <div class="text-danger small">
            失败 · 已重试 ${retryText} 次
          </div>
        `;
```

- [ ] **Step 2: Add retry button to job actions**

After the existing `downloadBtn` constant, add:

```js
      const retryBtn = ['failed', 'canceled'].includes(j.status)
        ? `<button class="btn btn-sm btn-outline-warning ms-1" onclick="retryJob(${j.id})">重试</button>`
        : '';
```

In the action cell, place `${retryBtn}` before `${exportedBadge}`:

```js
            ${openBtn}
            ${downloadBtn}
            ${retryBtn}
            ${exportedBadge}
            <button class="btn btn-sm btn-outline-danger ms-1" onclick="deleteJob(${j.id})">🗑️</button>
```

- [ ] **Step 3: Add `retryJob()` function**

After `downloadJob()` and before `deleteSelectedJobs()`, add:

```js
  async function retryJob(jobId) {
    await api(`/api/jobs/${jobId}/retry`, { method: 'POST' });
    await refreshJobs();
  }
```

- [ ] **Step 4: Export `retryJob` on `window`**

Near the existing global exports at the bottom of `ovd/static/index.html`, add:

```js
  window.retryJob = retryJob;
```

- [ ] **Step 5: Run frontend syntax check**

Run:

```bash
node --check ovd/static/index.html
```

Expected: exit code 0 with no syntax errors.

- [ ] **Step 6: Commit task 5**

```bash
git add ovd/static/index.html
git commit -m "feat(ui): 添加失败任务重试按钮"
```

---

### Task 6: Final verification

**Files:**
- Verify: `ovd/downloader/jobs.py`
- Verify: `ovd/web/app.py`
- Verify: `ovd/static/index.html`
- Verify: `tests/test_jobs.py`
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
node --check ovd/static/index.html
```

Expected: exit code 0 with no syntax errors.

- [ ] **Step 3: Check git status**

Run:

```bash
git status --short
```

Expected: only known local untracked files remain, such as `.claude/` or `ovd.exe`; no unstaged implementation files.

- [ ] **Step 4: Commit any final verification-only fix if needed**

If Step 1 or Step 2 reveals a real implementation issue and a code fix is made, commit only the fixed files:

```bash
git add ovd/downloader/jobs.py ovd/web/app.py ovd/static/index.html tests/test_jobs.py tests/test_bilibili.py
git commit -m "fix(downloader): 修复任务重试验证问题"
```

If no fix is needed, do not create an empty commit.

---

## Self-Review Notes

- Spec coverage: retry metadata, automatic retry, manual retry API, UI button, persistence, and tests are each mapped to a task.
- Placeholder scan: this plan contains no placeholder markers or undefined future work.
- Type consistency: retry fields are consistently named `retry_count` and `max_retries`; API route is consistently `POST /api/jobs/{job_id}/retry`; manager method is consistently `retry(job_id: int) -> bool`.
