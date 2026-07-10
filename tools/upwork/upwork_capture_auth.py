"""
upwork_capture_auth.py - Phase 1
用有頭 Chrome 登入 Upwork，攔截 API response 並保存 auth 資訊。

執行方式：
    python upwork_capture_auth.py

輸出：
    upwork_state.json   - Playwright browser storage state（cookies + localStorage）
    upwork_auth.json    - 攔截到的 API headers 和 GraphQL response 範例
"""

import asyncio
import json
import os
import re
import sys
from pathlib import Path
from playwright.async_api import async_playwright

try:
    from dotenv import load_dotenv
except ImportError:
    print("❌ 缺少 python-dotenv，請執行：pip install python-dotenv")
    sys.exit(1)

# 讀取 .env
ROOT_DIR = Path(__file__).resolve().parents[2]
_env_path = ROOT_DIR / ".env"
load_dotenv(dotenv_path=_env_path)

UPWORK_EMAIL = os.getenv("UPWORK_EMAIL", "").strip()
UPWORK_PASSWORD = os.getenv("UPWORK_PASSWORD", "").strip()

if not _env_path.exists():
    print("❌ 找不到 .env 檔案。")
    print(f"   請在 {_env_path.parent} 建立 .env，內容範例：")
    print("   UPWORK_EMAIL=your@email.com")
    print("   UPWORK_PASSWORD=yourpassword")
    sys.exit(1)

if not UPWORK_EMAIL or not UPWORK_PASSWORD:
    print("❌ .env 裡的 UPWORK_EMAIL 或 UPWORK_PASSWORD 為空。")
    print(f"   請編輯 {_env_path} 並填入正確的帳號密碼。")
    sys.exit(1)

STATE_PATH = ROOT_DIR / "data" / "upwork" / "private" / "upwork_state.json"
AUTH_PATH = ROOT_DIR / "data" / "upwork" / "private" / "upwork_auth.json"

# 要觸發的搜尋關鍵字（只是為了讓 API 被呼叫，抓到 schema）
PROBE_QUERY = "Google Apps Script"

# 要攔截的 API URL pattern
API_PATTERNS = [
    r"upwork\.com/api/graphql",
    r"upwork\.com/ab/jobs/search",
    r"upwork\.com/api/profiles",
]


def is_target_url(url: str) -> bool:
    return any(re.search(p, url) for p in API_PATTERNS)


async def capture_auth():
    captured = {
        "request_headers": {},
        "graphql_responses": [],
        "rest_responses": [],
    }

    print("=" * 60)
    print("Phase 1：Upwork Auth 攔截器")
    print("=" * 60)
    print("步驟：")
    print("  1. Chrome 視窗會打開，自動填入帳號密碼並點擊登入")
    print("  2. 請手動完成 Turnstile 驗證（程式不會自動操作）")
    print("  3. 登入後程式會自動觸發搜尋，攔截 API response")
    print("  4. 完成後關閉視窗或等待程式結束")
    print("=" * 60)
    print(f"📧 使用帳號：{UPWORK_EMAIL}")

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=False,
            channel="chrome",  # 用本機安裝的 Chrome，fingerprint 更正常
            args=["--start-maximized"],
        )
        context = await browser.new_context(
            viewport=None,  # 配合 --start-maximized
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
        )
        page = await context.new_page()

        # ── 攔截 Response ──────────────────────────────────────────
        async def handle_response(response):
            url = response.url
            if not is_target_url(url):
                return
            try:
                # 抓 request headers（包含 Authorization / cookie）
                req_headers = response.request.headers
                for key in [
                    "authorization",
                    "cookie",
                    "x-upwork-accept-language",
                    "x-user-timezone",
                    "x-requested-with",
                ]:
                    if key in req_headers and key not in captured["request_headers"]:
                        captured["request_headers"][key] = req_headers[key]

                # 抓 response body
                status = response.status
                if status == 200:
                    body = await response.json()
                    entry = {"url": url, "status": status, "body": body}
                    if "graphql" in url:
                        captured["graphql_responses"].append(entry)
                        print(f"  [GraphQL] 攔截到 response，URL: {url[:70]}")
                    else:
                        captured["rest_responses"].append(entry)
                        print(f"  [REST] 攔截到 response，URL: {url[:70]}")
                else:
                    print(f"  [跳過] {status} {url[:70]}")
            except Exception as e:
                pass  # 非 JSON response 忽略

        page.on("response", handle_response)

        # ── 前往登入頁 ─────────────────────────────────────────────
        await page.goto(
            "https://www.upwork.com/ab/account-security/login",
            wait_until="domcontentloaded",
            timeout=60000,
        )

        # ── 自動填入帳號密碼 ───────────────────────────────────────
        print("\n🤖 自動填入帳號...")
        try:
            await page.wait_for_selector("#login_username", timeout=15000)
            await page.fill("#login_username", UPWORK_EMAIL)
            await page.click("#login_password_continue")
            await page.wait_for_selector("#login_password", timeout=15000)
            await page.fill("#login_password", UPWORK_PASSWORD)
            await page.click("#login_control_continue")
            print("   ✅ 帳號密碼已填入並點擊登入")
        except Exception as e:
            print(f"   ⚠️  自動填入失敗（{e}），請手動登入")

        print("\n⏳ 等待 Turnstile 驗證完成（請手動通過，最多 3 分鐘）...")
        print("   程式不會自動操作驗證，請在瀏覽器中完成。\n")

        # 等待登入成功（偵測跳轉到 find-work 或 home）
        try:
            await page.wait_for_url(
                re.compile(r"upwork\.com/(nx/find-work|home|ab/dashboard)"),
                timeout=180000,
            )
            print("✅ 登入成功！開始攔截 API...\n")
        except Exception:
            print("⚠️  等待逾時，嘗試繼續執行（可能已登入）...")

        # ── 觸發搜尋讓 API 被呼叫 ──────────────────────────────────
        print(f"🔍 觸發搜尋：{PROBE_QUERY}")
        search_url = (
            f"https://www.upwork.com/nx/search/jobs/"
            f"?q={PROBE_QUERY.replace(' ', '+')}&sort=recency"
        )
        await page.goto(search_url, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(5000)  # 等待非同步請求完成

        # 滾動一次觸發更多請求
        await page.evaluate("window.scrollTo(0, 800)")
        await page.wait_for_timeout(3000)

        # ── 保存 storage state ──────────────────────────────────────
        print("\n💾 保存 browser storage state...")
        await context.storage_state(path=str(STATE_PATH))
        print(f"   → {STATE_PATH}")

        # 補充 cookies 到 auth（方便 httpx 直接用）
        cookies = await context.cookies()
        cookie_str = "; ".join([f"{c['name']}={c['value']}" for c in cookies])
        if "cookie" not in captured["request_headers"]:
            captured["request_headers"]["cookie"] = cookie_str

        # 記錄重要 cookie
        oauth_cookies = {
            c["name"]: c["value"]
            for c in cookies
            if any(k in c["name"].lower() for k in ["oauth", "token", "auth", "sess"])
        }
        captured["oauth_cookies"] = oauth_cookies
        captured["all_cookies_str"] = cookie_str

        with open(AUTH_PATH, "w", encoding="utf-8") as f:
            json.dump(captured, f, ensure_ascii=False, indent=2)
        print(f"   → {AUTH_PATH}")

        print(f"\n📊 攔截統計：")
        print(f"   GraphQL responses: {len(captured['graphql_responses'])}")
        print(f"   REST responses:    {len(captured['rest_responses'])}")
        print(f"   Auth headers:      {list(captured['request_headers'].keys())}")
        print(f"   OAuth cookies:     {list(oauth_cookies.keys())}")

        if not captured["graphql_responses"] and not captured["rest_responses"]:
            print("\n⚠️  警告：沒有攔截到任何 API response。")
            print("   可能原因：登入未完成、網路問題、Upwork 改版。")
            print("   建議：在瀏覽器中手動搜尋一次後重試。")

        await browser.close()
        print("\n✅ Phase 1 完成！接下來可以執行 upwork_api_search.py")


if __name__ == "__main__":
    asyncio.run(capture_auth())
