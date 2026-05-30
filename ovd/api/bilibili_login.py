"""Bilibili 扫码登录，自动获取 Cookies。"""

from __future__ import annotations

import asyncio
import urllib.parse
from dataclasses import dataclass
from http.cookies import SimpleCookie
from io import BytesIO

import httpx

try:
    from PIL import Image, ImageShow
    HAS_PIL = True
except ImportError:
    HAS_PIL = False


@dataclass
class LoginResult:
    """登录结果。"""
    success: bool
    cookies: str = ""
    message: str = ""
    qrcode_url: str = ""
    login_url: str = ""
    qrcode_key: str = ""


class BiliBiliLogin:
    """Bilibili 扫码登录类。"""

    @staticmethod
    def _extract_cookies(resp: httpx.Response) -> str:
        cookie_parts = [f"{key}={value}" for key, value in resp.cookies.items()]
        set_cookie = resp.headers.get("set-cookie", "")
        if set_cookie:
            parsed = SimpleCookie()
            parsed.load(set_cookie)
            existing_names = {part.split("=", 1)[0] for part in cookie_parts}
            for key, morsel in parsed.items():
                if key not in existing_names:
                    cookie_parts.append(f"{key}={morsel.value}")
        return "; ".join(cookie_parts)

    def __init__(self):
        self._headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Referer": "https://www.bilibili.com/",
        }
        self._cookies = {}
        self._qrcode_key = ""

    async def get_qrcode(self) -> LoginResult:
        """获取登录二维码。

        返回: LoginResult，包含二维码 URL 和 qrcode_key
        """
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                "https://passport.bilibili.com/x/passport-login/web/qrcode/generate",
                headers=self._headers,
            )
            data = resp.json()

            if data.get("code") != 0:
                return LoginResult(
                    success=False,
                    message="获取二维码失败: " + data.get("message", "未知错误"),
                )

            result_data = data.get("data", {})
            self._qrcode_key = result_data.get("qrcode_key", "")
            
            login_url = result_data.get("url", "")
            encoded_login_url = urllib.parse.quote(login_url, safe="")
            qrcode_image_url = f"https://api.qrserver.com/v1/create-qr-code/?size=240x240&data={encoded_login_url}"

            return LoginResult(
                success=True,
                qrcode_url=qrcode_image_url,
                login_url=login_url,
                qrcode_key=self._qrcode_key,
                message="请使用 Bilibili APP 扫码登录",
            )

    async def check_login(self, qrcode_key: str = "") -> LoginResult:
        """检查扫码状态。

        Returns:
            - 0: 二维码未过期，未扫码
            - 86090: 已扫码，未确认
            - 86101: 已扫码，已取消
            - 86038: 二维码已失效
            - 0 且有 cookies: 登录成功
        """
        if not qrcode_key and not self._qrcode_key:
            return LoginResult(success=False, message="请先获取二维码")

        key = qrcode_key or self._qrcode_key

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.get(
                "https://passport.bilibili.com/x/passport-login/web/qrcode/poll",
                params={"qrcode_key": key},
                headers=self._headers,
            )
            data = resp.json()

        result_data = data.get("data", {})
        code = result_data.get("code", -1)
        message = result_data.get("message", "")

        # 登录成功：data.code == 0
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

        # 其他状态（B站状态码含义）
        # 86101 = 未扫码（正常等待）
        # 86090 = 已扫码，未确认（需要用户在手机上点击「确认登录」）
        # 86038 = 已失效
        # 86102 = 已取消
        status_messages = {
            86090: "✓ 已扫码，请在手机上点击「确认登录」",
            86101: "未扫码，请用 Bilibili APP 扫码",
            86102: "已取消，请重新扫码",
            86038: "二维码已失效，请重新获取",
        }

        return LoginResult(
            success=False,
            message=status_messages.get(code, message or f"状态码: {code}"),
        )

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

    async def login_and_get_cookies(self, show_qrcode: bool = False) -> LoginResult:
        """完整登录流程：获取二维码 -> 等待扫码 -> 返回 cookies。

        Args:
            show_qrcode: 是否在终端显示二维码（需要 PIL 库）
        """
        # 1. 获取二维码
        result = await self.get_qrcode()
        if not result.success:
            return result

        print(f"\n=== Bilibili 扫码登录 ===")
        print(f"二维码链接: {result.qrcode_url}")
        print()

        # 如果支持 PIL，在终端显示二维码
        if show_qrcode and HAS_PIL:
            try:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(result.qrcode_url)
                    img = Image.open(BytesIO(resp.content))
                    # 缩小以便在终端显示
                    img = img.resize((50, 50))
                    # 转换为 ASCII
                    ascii_img = self._image_to_ascii(img)
                    print(ascii_img)
            except Exception:
                print("（请在浏览器中打开上面的链接查看二维码）")
        else:
            print("请在浏览器中打开上面的链接，用 Bilibili APP 扫码")

        print()
        print("等待扫码...（按 Ctrl+C 取消）")

        # 2. 轮询检查登录状态，最多 2 分钟
        for _ in range(60):
            await asyncio.sleep(2)
            check = await self.check_login(result.qrcode_key)
            if check.success and check.cookies:
                print(f"✓ {check.message}")
                return check
            elif "已失效" in check.message or "已取消" in check.message:
                print(f"✗ {check.message}")
                return check
            elif "已扫码" in check.message:
                print(f"→ {check.message}...")

        return LoginResult(success=False, message="等待超时，请重试")

    def _image_to_ascii(self, img: Image.Image) -> str:
        """将图片转换为 ASCII 字符画。"""
        chars = " .:-=+*#%@"
        img = img.convert("L")
        lines = []
        for y in range(img.height):
            line = []
            for x in range(img.width):
                pixel = img.getpixel((x, y))
                char = chars[int(pixel / 255 * (len(chars) - 1))]
                line.append(char * 2)  # 每个像素打印两个字符，修正比例
            lines.append("".join(line))
        return "\n".join(lines)


async def main():
    """命令行测试：直接扫码登录并输出 cookies。"""
    login = BiliBiliLogin()
    result = await login.login_and_get_cookies(show_qrcode=True)
    if result.success and result.cookies:
        print()
        print("=" * 60)
        print("获取到的 Cookies:")
        print("=" * 60)
        print(result.cookies)
        print("=" * 60)
        print()
        print("请将上面的 Cookies 复制粘贴到程序设置中。")
    else:
        print(f"登录失败: {result.message}")


if __name__ == "__main__":
    asyncio.run(main())
