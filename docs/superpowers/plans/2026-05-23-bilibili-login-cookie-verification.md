# Bilibili Login Cookie Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Bilibili QR-code login report success only after cookies are extracted, verified against Bilibili login state, saved, and reflected in the frontend.

**Architecture:** `BiliBiliLogin` owns QR-code polling, cookie extraction, and cookie verification. The FastAPI login check endpoint saves cookies only after verification succeeds and returns a user-facing success message. The single-page frontend consumes that message, refreshes settings state, and clearly shows that cookies were saved.

**Tech Stack:** Python 3, FastAPI, httpx, pytest, FastAPI TestClient, vanilla HTML/JavaScript.

---

## File Structure

- Modify: `ovd/api/bilibili_login.py`
  - Fix login success detection for QR-code poll responses.
  - Add `verify_cookies(cookies: str) -> bool` using Bilibili nav API.
- Modify: `ovd/web/app.py`
  - In `/api/bilibili/login/check/{session_id}`, verify cookies before saving.
  - Return the exact success message `登录成功，Cookies 已保存成功`.
  - Return a failure message and do not save if verification fails.
- Modify: `ovd/static/index.html`
  - Show the backend message on success.
  - Refresh Bilibili settings after successful login so the checkbox and masked cookies state update immediately.
  - Show verification failure messages in the QR-code status area.
- Modify: `tests/test_bilibili_login.py`
  - Add unit coverage for poll success detection and cookie verification.
- Modify: `tests/test_bilibili.py`
  - Add API endpoint tests for verified save and failed verification.

---

### Task 1: Fix QR Login Success Detection and Cookie Verification

**Files:**
- Modify: `ovd/api/bilibili_login.py:20-140`
- Test: `tests/test_bilibili_login.py`

- [ ] **Step 1: Add failing tests for successful poll without `refresh_token` field and cookie verification**

Append these tests to `tests/test_bilibili_login.py`:

```python
@pytest.mark.asyncio
async def test_check_login_accepts_success_url_and_sessdata_cookie(monkeypatch):
    FakeClient.response = FakeResponse(
        {
            "code": 0,
            "data": {
                "code": 0,
                "message": "",
                "url": "https://www.bilibili.com/?refresh_token=token",
            },
        },
        headers={
            "set-cookie": "SESSDATA=session-value; Path=/; Domain=.bilibili.com, bili_jct=jct-value; Path=/; Domain=.bilibili.com",
        },
    )
    monkeypatch.setattr("ovd.api.bilibili_login.httpx.AsyncClient", FakeClient)

    result = await BiliBiliLogin().check_login("abc")

    assert result.success is True
    assert result.message == "登录成功！"
    assert "SESSDATA=session-value" in result.cookies
    assert "bili_jct=jct-value" in result.cookies


@pytest.mark.asyncio
async def test_check_login_rejects_success_poll_without_cookies(monkeypatch):
    FakeClient.response = FakeResponse(
        {
            "code": 0,
            "data": {
                "code": 0,
                "message": "",
                "url": "https://www.bilibili.com/?refresh_token=token",
            },
        },
        headers={},
    )
    monkeypatch.setattr("ovd.api.bilibili_login.httpx.AsyncClient", FakeClient)

    result = await BiliBiliLogin().check_login("abc")

    assert result.success is False
    assert result.message == "登录成功但未获取到有效 Cookies，请重新扫码"


@pytest.mark.asyncio
async def test_verify_cookies_returns_true_for_logged_in_nav(monkeypatch):
    class NavResponse:
        def json(self):
            return {"code": 0, "data": {"isLogin": True}}

    class NavClient:
        captured_headers = None

        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, url, *args, **kwargs):
            NavClient.captured_headers = kwargs.get("headers")
            return NavResponse()

    monkeypatch.setattr("ovd.api.bilibili_login.httpx.AsyncClient", NavClient)

    ok = await BiliBiliLogin().verify_cookies("SESSDATA=session-value; bili_jct=jct-value")

    assert ok is True
    assert NavClient.captured_headers["Cookie"] == "SESSDATA=session-value; bili_jct=jct-value"


@pytest.mark.asyncio
async def test_verify_cookies_returns_false_for_logged_out_nav(monkeypatch):
    class NavResponse:
        def json(self):
            return {"code": 0, "data": {"isLogin": False}}

    class NavClient:
        def __init__(self, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return False

        async def get(self, *args, **kwargs):
            return NavResponse()

    monkeypatch.setattr("ovd.api.bilibili_login.httpx.AsyncClient", NavClient)

    ok = await BiliBiliLogin().verify_cookies("SESSDATA=session-value")

    assert ok is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_bilibili_login.py -v
```

Expected: at least `test_check_login_accepts_success_url_and_sessdata_cookie`, `test_check_login_rejects_success_poll_without_cookies`, and the `verify_cookies` tests fail because `check_login` still requires `refresh_token` and `verify_cookies` does not exist.

- [ ] **Step 3: Implement success detection and cookie verification**

In `ovd/api/bilibili_login.py`, replace the success block in `check_login` around `code == 0` with:

```python
        if code == 0:
            cookie_str = self._extract_cookies(resp)
            if "SESSDATA=" not in cookie_str:
                return LoginResult(
                    success=False,
                    message="登录成功但未获取到有效 Cookies，请重新扫码",
                )

            return LoginResult(
                success=True,
                cookies=cookie_str,
                message="登录成功！",
            )
```

Then add this method to `BiliBiliLogin` after `check_login` and before `login_and_get_cookies`:

```python
    async def verify_cookies(self, cookies: str) -> bool:
        if not cookies.strip():
            return False

        headers = dict(self._headers)
        headers["Cookie"] = cookies
        try:
            async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
                resp = await client.get(
                    "https://api.bilibili.com/x/web-interface/nav",
                    headers=headers,
                )
                data = resp.json()
        except Exception:
            return False

        return data.get("code") == 0 and bool(data.get("data", {}).get("isLogin"))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
pytest tests/test_bilibili_login.py -v
```

Expected: all tests in `tests/test_bilibili_login.py` pass.

- [ ] **Step 5: Commit**

Do not commit unless the user explicitly asks for commits. If committing is requested later, stage only these files:

```bash
git add ovd/api/bilibili_login.py tests/test_bilibili_login.py
git commit -m "fix(bilibili): 修正扫码登录 Cookie 校验"
```

---

### Task 2: Verify Cookies Before Saving in FastAPI Login Endpoint

**Files:**
- Modify: `ovd/web/app.py:695-727`
- Test: `tests/test_bilibili.py`

- [ ] **Step 1: Add failing API tests for verified save and failed verification**

Append these tests to `tests/test_bilibili.py`:

```python
def test_bilibili_login_check_saves_only_verified_cookies(monkeypatch, tmp_path):
    from ovd.web import app as app_module

    class FakeSettings:
        def __init__(self):
            self.download_dir = tmp_path
            self.saved = None

        def save_bilibili_settings(self, enabled, cookies):
            self.saved = {"enabled": enabled, "cookies": cookies}

    class FakeLogin:
        async def check_login(self, qrcode_key):
            from ovd.api.bilibili_login import LoginResult
            return LoginResult(success=True, cookies="SESSDATA=session-value", message="登录成功！")

        async def verify_cookies(self, cookies):
            return True

    fake_settings = FakeSettings()
    app_module._bilibili_login_sessions.clear()
    app_module._bilibili_login_sessions["session-ok"] = {
        "login": FakeLogin(),
        "qrcode_key": "abc",
        "created_at": 0,
    }

    monkeypatch.setattr(app_module.Settings, "load_from_dir", lambda download_dir: fake_settings)
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
    assert "session-ok" not in app_module._bilibili_login_sessions


def test_bilibili_login_check_does_not_save_unverified_cookies(monkeypatch, tmp_path):
    from ovd.web import app as app_module

    class FakeSettings:
        def __init__(self):
            self.download_dir = tmp_path
            self.saved = None

        def save_bilibili_settings(self, enabled, cookies):
            self.saved = {"enabled": enabled, "cookies": cookies}

    class FakeLogin:
        async def check_login(self, qrcode_key):
            from ovd.api.bilibili_login import LoginResult
            return LoginResult(success=True, cookies="SESSDATA=session-value", message="登录成功！")

        async def verify_cookies(self, cookies):
            return False

    fake_settings = FakeSettings()
    app_module._bilibili_login_sessions.clear()
    app_module._bilibili_login_sessions["session-bad"] = {
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
    assert "session-bad" not in app_module._bilibili_login_sessions
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
pytest tests/test_bilibili.py::test_bilibili_login_check_saves_only_verified_cookies tests/test_bilibili.py::test_bilibili_login_check_does_not_save_unverified_cookies -v
```

Expected: tests fail because the endpoint does not call `verify_cookies`, returns the old success message, and does not handle verification failure.

- [ ] **Step 3: Implement verified save behavior**

In `ovd/web/app.py`, replace the `if result.success and result.cookies:` block inside `api_bilibili_check_login` with:

```python
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
```

Keep the existing `else` return for pending/non-success states.

- [ ] **Step 4: Run endpoint tests**

Run:

```bash
pytest tests/test_bilibili.py::test_bilibili_login_check_saves_only_verified_cookies tests/test_bilibili.py::test_bilibili_login_check_does_not_save_unverified_cookies -v
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

Do not commit unless the user explicitly asks for commits. If committing is requested later, stage only these files:

```bash
git add ovd/web/app.py tests/test_bilibili.py
git commit -m "fix(bilibili): 登录成功后校验并保存 Cookies"
```

---

### Task 3: Update Frontend Success and Failure Feedback

**Files:**
- Modify: `ovd/static/index.html:1245-1268`

- [ ] **Step 1: Make the success branch show backend message and refresh settings**

In `ovd/static/index.html`, replace the `if (result.success) { ... }` branch inside the QR-code polling interval with:

```javascript
          if (result.success) {
            clearInterval(_bilibiliPollTimer);
            _bilibiliPollTimer = null;
            $('#bilibiliLoginStatus').textContent = `✓ ${result.message || '登录成功，Cookies 已保存成功'}`;
            $('#bilibiliLoginStatus').className = 'mt-2 mb-0 small text-success fw-bold';
            await loadBilibiliSettings();
            alert(result.message || '登录成功，Cookies 已保存成功');
            setTimeout(() => {
              $('#bilibiliQrcodeArea').style.display = 'none';
              $('#bilibiliLoginStatus').className = 'mt-2 mb-0 small text-muted';
            }, 3000);
          } else if (result.has_cookies === false && result.message.includes('校验失败')) {
            clearInterval(_bilibiliPollTimer);
            _bilibiliPollTimer = null;
            $('#bilibiliLoginStatus').textContent = result.message;
            $('#bilibiliLoginStatus').className = 'mt-2 mb-0 small text-danger fw-bold';
```

Leave the existing `已失效`, `已扫码`, and `已取消` branches immediately after this new verification-failure branch.

- [ ] **Step 2: Ensure timeout cleanup resets timer variable**

In the timeout branch around `if (checkCount > 150)`, change:

```javascript
          clearInterval(_bilibiliPollTimer);
```

to:

```javascript
          clearInterval(_bilibiliPollTimer);
          _bilibiliPollTimer = null;
```

- [ ] **Step 3: Manually inspect the JavaScript syntax**

Run:

```bash
python - <<'PY'
from pathlib import Path
text = Path('ovd/static/index.html').read_text(encoding='utf-8')
start = text.index('      _bilibiliPollTimer = setInterval')
end = text.index('    } catch (e) {', start)
print(text[start:end])
PY
```

Expected: the printed block has balanced braces and the branch order is `result.success`, verification failure, expired, scanned, canceled.

- [ ] **Step 4: Commit**

Do not commit unless the user explicitly asks for commits. If committing is requested later, stage only this file:

```bash
git add ovd/static/index.html
git commit -m "fix(ui): 显示 B 站 Cookies 保存成功提示"
```

---

### Task 4: Run Verification

**Files:**
- No new files.
- Verify changes across `ovd/api/bilibili_login.py`, `ovd/web/app.py`, `ovd/static/index.html`, `tests/test_bilibili_login.py`, `tests/test_bilibili.py`.

- [ ] **Step 1: Run focused tests**

Run:

```bash
pytest tests/test_bilibili_login.py tests/test_bilibili.py -v
```

Expected: all tests pass.

- [ ] **Step 2: Run broader test suite**

Run:

```bash
pytest -v
```

Expected: all tests pass. If unrelated tests fail, record the exact failure and do not claim the whole suite passes.

- [ ] **Step 3: Start the web server for UI verification**

Run:

```bash
python -m uvicorn ovd.web.app:app --host 127.0.0.1 --port 8000
```

Expected: server starts and serves the app at `http://127.0.0.1:8000/`.

- [ ] **Step 4: Manually verify QR-code login UI**

In the browser:

1. Open the local app.
2. Click the settings button.
3. Click `扫码登录（自动获取Cookies）`.
4. Scan the QR code with Bilibili APP.
5. Confirm login on the phone.
6. Confirm the status text shows `登录成功，Cookies 已保存成功`.
7. Confirm the cookies textarea changes to `******` and the Bilibili enabled checkbox is checked.
8. Confirm the QR-code area hides after about 3 seconds.

Expected: the UI clearly tells the user that cookies were saved, and Bilibili settings reflect saved cookies.

---

## Self-Review

- Spec coverage: Task 1 covers QR-code success detection and cookie verification; Task 2 covers verified saving and backend response; Task 3 covers frontend success/failure feedback and settings refresh; Task 4 covers automated and UI verification.
- Placeholder scan: no TBD/TODO/later placeholders remain in implementation steps.
- Type consistency: `verify_cookies(cookies: str) -> bool`, `LoginResult.success`, `LoginResult.cookies`, `has_cookies`, and all endpoint response keys are used consistently across tasks.
