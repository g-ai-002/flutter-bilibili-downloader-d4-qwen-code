"""单元测试: Bilibili 扫码登录。"""

import pytest

from ovd.api.bilibili_login import BiliBiliLogin


class FakeResponse:
    def __init__(self, payload, cookies=None, headers=None):
        self.payload = payload
        self.cookies = cookies or {}
        self.headers = headers or {}

    def json(self):
        return self.payload


class FakeClient:
    response = None

    def __init__(self, **kwargs):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def get(self, *args, **kwargs):
        return self.response


@pytest.mark.asyncio
async def test_get_qrcode_encodes_login_url_for_qr_image(monkeypatch):
    login_url = "https://passport.bilibili.com/h5-app/passport/login/scan?navhide=1&qrcode_key=abc&from=main"
    FakeClient.response = FakeResponse({
        "code": 0,
        "data": {"url": login_url, "qrcode_key": "abc"},
    })
    monkeypatch.setattr("ovd.api.bilibili_login.httpx.AsyncClient", FakeClient)

    result = await BiliBiliLogin().get_qrcode()

    assert result.success is True
    assert result.login_url == login_url
    assert "data=https%3A%2F%2Fpassport.bilibili.com" in result.qrcode_url
    assert "&from=main" not in result.qrcode_url


@pytest.mark.asyncio
async def test_check_login_extracts_cookie_from_set_cookie_headers(monkeypatch):
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
    assert "SESSDATA=session-value" in result.cookies
    assert "bili_jct=jct-value" in result.cookies


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
