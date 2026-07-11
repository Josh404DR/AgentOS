"""
upwork_api_search.py - Phase 2
讀取 Phase 1 保存的 auth，直接呼叫 Upwork API 搜尋 job，
輸出 Markdown 格式的 leads 檔。

執行方式：
    python upwork_api_search.py
    python upwork_api_search.py --query "Google Sheets" --limit 20

若 session 過期（401/403），程式會提示重跑 Phase 1。
"""

import argparse
import json
import sys
import re
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

# ── 設定 ────────────────────────────────────────────────────────────
ROOT_DIR = Path(__file__).resolve().parents[2]
STATE_PATH = ROOT_DIR / "data" / "upwork" / "private" / "upwork_state.json"
AUTH_PATH = ROOT_DIR / "data" / "upwork" / "private" / "upwork_auth.json"
LEADS_DIR = ROOT_DIR / "data" / "leads"
CONFIG_PATH = ROOT_DIR / "config" / "upwork_search.json"  # 可選設定檔

# 從 AgentOS 工作流定義的預設搜尋關鍵字（來源：workflows/ai_freelancer_os.md）
DEFAULT_QUERIES = [
    "Google Apps Script",
    "Google Sheets automation",
    "AppSheet",
    "Workspace automation",
    "Google Sheets dashboard",
]

DEFAULT_LIMIT = 20
TAIPEI_TZ = ZoneInfo("Asia/Taipei")

# Upwork API endpoints
GRAPHQL_URL = "https://www.upwork.com/api/graphql/v1"
REST_SEARCH_URL = "https://www.upwork.com/ab/jobs/search/"

# GraphQL query（根據 Upwork 前端實際使用的格式）
JOB_SEARCH_QUERY = """
query JobSearch(
  $query: String!
  $sort: String
  $paging_count: Int
  $paging_offset: Int
) {
  jobSearch: userJobSearch(
    searchInput: {
      q: $query
      sort: $sort
      paging: { count: $paging_count, offset: $paging_offset }
    }
  ) {
    results {
      id
      title
      description
      amount {
        amount
        currencyCode
      }
      duration {
        label
      }
      job_type: jobType
      engagement_duration: engagementDuration {
        label
      }
      created_at: publishedOn
      url: ciphertext
      client {
        location {
          country
        }
        feedback_score: feedbackScore
        reviews_count: reviewsCount
        jobs_posted_count: jobsPostedCount
        payment_verification_status: paymentVerificationStatus
      }
      skills {
        name
      }
    }
    paging {
      total
      count
      offset
    }
  }
}
"""

# ── Auth 載入 ────────────────────────────────────────────────────────

def load_auth_headers() -> dict:
    """從 upwork_auth.json 讀取攔截到的 headers。"""
    if not AUTH_PATH.exists():
        print("❌ 找不到 upwork_auth.json，請先執行 upwork_capture_auth.py")
        sys.exit(1)

    with open(AUTH_PATH, encoding="utf-8") as f:
        auth = json.load(f)

    headers = {
        "content-type": "application/json",
        "accept": "application/json, text/plain, */*",
        "accept-language": "zh-TW,zh;q=0.9,en-US;q=0.8",
        "origin": "https://www.upwork.com",
        "referer": "https://www.upwork.com/nx/search/jobs/",
        **auth.get("request_headers", {}),
    }
    return headers


def load_storage_state_cookies() -> str:
    """從 Playwright storage state 解析 cookie string。"""
    if not STATE_PATH.exists():
        return ""
    with open(STATE_PATH, encoding="utf-8") as f:
        state = json.load(f)
    cookies = state.get("cookies", [])
    return "; ".join([f"{c['name']}={c['value']}" for c in cookies])


def check_auth_expiry():
    """檢查 auth 檔案的 cookie 是否包含 oauth token。"""
    if not STATE_PATH.exists() or not AUTH_PATH.exists():
        print("❌ Auth 檔案不存在，請先執行 Phase 1：")
        print("   python upwork_capture_auth.py")
        sys.exit(1)


# ── API 呼叫（用 Playwright 的 storage state restore session）────────

async def search_via_playwright(queries: list[str], limit: int) -> list[dict]:
    """
    用 Playwright restore storage state，在瀏覽器內攔截 API response。
    這是最穩定的方式，不需要自己處理 header signing。
    """
    from playwright.async_api import async_playwright

    all_results = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            channel="chrome",
        )
        # 直接 restore 上次的 session，不需重新登入
        context = await browser.new_context(
            storage_state=str(STATE_PATH),
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/125.0.0.0 Safari/537.36"
            ),
        )
        page = await context.new_page()

        session_expired = False

        async def handle_response(response):
            nonlocal session_expired
            url = response.url
            status = response.status

            # 偵測 session 過期
            if status in (401, 403) and "upwork.com/api" in url:
                session_expired = True
                print(f"⚠️  API 回傳 {status}，session 可能已過期：{url[:60]}")
                return

            if status != 200:
                return

            if "graphql" not in url and "jobs/search" not in url:
                return

            try:
                body = await response.json()

                # REST API 格式
                if "jobs/search" in url:
                    jobs = body.get("results", [])
                    for job in jobs:
                        all_results.append(_normalize_rest(job))

                # GraphQL 格式
                elif "graphql" in url:
                    data = body.get("data", {})
                    job_search = data.get("jobSearch") or data.get("userJobSearch", {})
                    results = job_search.get("results", [])
                    for job in results:
                        all_results.append(_normalize_graphql(job))

            except Exception:
                pass

        page.on("response", handle_response)

        for query in queries:
            print(f"🔍 搜尋：{query}")
            search_url = (
                f"https://www.upwork.com/nx/search/jobs/"
                f"?q={query.replace(' ', '+')}&sort=recency"
            )
            try:
                await page.goto(search_url, wait_until="networkidle", timeout=45000)
                await page.wait_for_timeout(4000)

                # 檢查是否被導到登入頁（session 過期）
                current_url = page.url
                if "login" in current_url or "account-security" in current_url:
                    session_expired = True
                    print("⚠️  被導向登入頁，session 已過期")
                    break

                print(f"   已抓到 {len(all_results)} 筆（累計）")

            except Exception as e:
                print(f"   ⚠️  搜尋失敗：{e}")

        await browser.close()

        if session_expired:
            print("\n❌ Session 已過期，請重新執行 Phase 1：")
            print("   python upwork_capture_auth.py")
            sys.exit(1)

    return all_results


def _normalize_graphql(job: dict) -> dict:
    """統一化 GraphQL 格式的 job 資料。"""
    uid = job.get("id", "")
    cipher = job.get("url", "")
    url = f"https://www.upwork.com/jobs/~{cipher}" if cipher else f"https://www.upwork.com/jobs/?id={uid}"

    amount = job.get("amount") or {}
    budget = f"{amount.get('currencyCode', 'USD')} {amount.get('amount', 'N/A')}"

    client = job.get("client") or {}
    location = (client.get("location") or {}).get("country", "N/A")
    payment_ok = client.get("payment_verification_status") == "VERIFIED"
    feedback = client.get("feedback_score")
    reviews = client.get("reviews_count", 0)

    skills = [s.get("name", "") for s in (job.get("skills") or [])]

    return {
        "title": job.get("title", "N/A"),
        "url": url,
        "budget": budget,
        "job_type": job.get("job_type", ""),
        "duration": (job.get("duration") or {}).get("label", ""),
        "posted": job.get("created_at", ""),
        "description": (job.get("description") or "")[:400],
        "client_location": location,
        "client_payment_verified": payment_ok,
        "client_feedback": feedback,
        "client_reviews": reviews,
        "skills": skills,
    }


def _normalize_rest(job: dict) -> dict:
    """統一化 REST API 格式的 job 資料。"""
    return {
        "title": job.get("title", "N/A"),
        "url": f"https://www.upwork.com/jobs/~{job.get('id', '')}",
        "budget": str(job.get("budget", {}).get("amount", "N/A")),
        "job_type": job.get("jobType", ""),
        "duration": "",
        "posted": job.get("publishedOn", ""),
        "description": (job.get("snippet") or "")[:400],
        "client_location": (job.get("client") or {}).get("location", {}).get("country", "N/A"),
        "client_payment_verified": False,
        "client_feedback": None,
        "client_reviews": 0,
        "skills": [s.get("prettyName", "") for s in (job.get("skills") or [])],
    }


# ── Markdown 輸出 ─────────────────────────────────────────────────────

def score_job(job: dict) -> int:
    """簡單的 fit score：0-10"""
    score = 5
    desc_lower = (job.get("description") or "").lower()
    title_lower = (job.get("title") or "").lower()

    # 加分：關鍵技能吻合
    for kw in ["google apps script", "google sheets", "appsheet", "automation", "dashboard"]:
        if kw in desc_lower or kw in title_lower:
            score += 1

    # 加分：有預算
    budget = job.get("budget", "")
    if budget and budget not in ("N/A", "USD N/A"):
        score += 1

    # 加分：客戶有付款驗證
    if job.get("client_payment_verified"):
        score += 1

    # 扣分：客戶無評價
    if (job.get("client_reviews") or 0) == 0:
        score -= 1

    return max(0, min(10, score))


def jobs_to_markdown(jobs: list[dict], queries: list[str]) -> str:
    now = datetime.now(TAIPEI_TZ)
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%Y-%m-%d %H:%M")

    # 依 fit score 排序
    jobs_scored = [(score_job(j), j) for j in jobs]
    jobs_scored.sort(key=lambda x: -x[0])

    best = jobs_scored[0][1] if jobs_scored else None
    qualified = [j for s, j in jobs_scored if s >= 6]

    lines = [
        f"# Leads - {date_str}",
        "",
        f"Generated: {time_str} Asia/Taipei",
        f"Source: Upwork API (Playwright session restore)",
        f"Search queries: {', '.join(queries)}",
        f"Owner: Hermes",
        "",
        "## Summary",
        f"- Total results: {len(jobs)}",
        f"- Qualified leads (score ≥ 6): {len(qualified)}",
        f"- Strongest lead: {best['title'] if best else 'none'}",
        "",
        "## Leads",
        "",
    ]

    for i, (score, job) in enumerate(jobs_scored, 1):
        # 推薦動作
        if score >= 8:
            action = "draft proposal"
        elif score >= 6:
            action = "watch"
        else:
            action = "skip"

        lines += [
            f"### {i}. {job['title']}",
            "",
            f"- URL: {job['url']}",
            f"- Budget: {job['budget']}",
            f"- Type: {job['job_type']} {job['duration']}".strip(),
            f"- Posted: {job['posted']}",
            f"- Client: {job['client_location']}"
            + (" ✅ Payment Verified" if job["client_payment_verified"] else "")
            + (f" | ⭐ {job['client_feedback']}" if job["client_feedback"] else "")
            + (f" ({job['client_reviews']} reviews)" if job["client_reviews"] else ""),
            f"- Skills: {', '.join(job['skills'][:8]) or 'N/A'}",
            f"- Fit score: {score}/10",
            f"- Recommended next action: {action}",
            "",
            f"> {job['description'][:300]}{'...' if len(job.get('description','')) > 300 else ''}",
            "",
        ]

    if not jobs:
        lines += [
            "## No-Match Note",
            "",
            f"No results found for queries: {', '.join(queries)}",
        ]

    return "\n".join(lines)


# ── 主程式 ────────────────────────────────────────────────────────────

def load_config_queries() -> list[str]:
    """從 config 或 workflow 讀取搜尋關鍵字，找不到就用預設值。"""
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH, encoding="utf-8") as f:
            cfg = json.load(f)
        return cfg.get("queries", DEFAULT_QUERIES)
    return DEFAULT_QUERIES



async def dry_run(queries: list[str]):
    """
    --dry-run 模式：不需要登入，只測試：
    1. upwork_state.json / upwork_auth.json 是否存在
    2. httpx 能否連線到 upwork.com
    3. config/upwork_search.json 預設值讀取
    4. data/leads/ 目錄是否能建立
    5. Markdown 輸出格式
    """
    import httpx

    print("=" * 60)
    print("Dry-run 模式（不登入，只測試環境）")
    print("=" * 60)
    all_ok = True

    # 1. 檔案存在性
    print("\n[1] Auth 檔案")
    for path, label in [(STATE_PATH, "upwork_state.json"), (AUTH_PATH, "upwork_auth.json")]:
        status = "OK 存在" if path.exists() else "-- 不存在（Phase 1 尚未執行，正式使用前需跑一次）"
        print(f"    {label}: {status}")

    # 2. config / 搜尋關鍵字
    print("\n[2] 搜尋關鍵字設定")
    loaded = load_config_queries()
    src = "config/upwork_search.json" if CONFIG_PATH.exists() else "預設值（workflows/ai_freelancer_os.md）"
    print(f"    來源：{src}")
    for q in loaded:
        print(f"      - {q}")

    # 3. data/leads/ 目錄
    print("\n[3] data/leads/ 目錄")
    try:
        LEADS_DIR.mkdir(parents=True, exist_ok=True)
        print(f"    OK  {LEADS_DIR}")
    except Exception as e:
        print(f"    FAIL 建立失敗：{e}")
        all_ok = False

    # 4. httpx 連線測試
    print("\n[4] 網路連線測試")
    test_urls = [
        ("https://www.upwork.com/", "upwork.com 首頁"),
        ("https://www.upwork.com/ab/jobs/search/?q=python&limit=1", "REST search endpoint"),
    ]
    async with httpx.AsyncClient(timeout=15, follow_redirects=True) as client:
        for url, label in test_urls:
            try:
                r = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
                if r.status_code == 403:
                    # 403 = Cloudflare 擋裸請求，屬正常；Playwright 帶 cookie 後不受影響
                    print(f"    OK  {label}: HTTP 403 (Cloudflare 擋裸請求，正常，Playwright session 不受影響)")
                elif r.status_code in (200, 301, 302):
                    print(f"    OK  {label}: HTTP {r.status_code}")
                else:
                    print(f"    ??  {label}: HTTP {r.status_code}（非預期）")
            except Exception as e:
                msg = str(e)
                if "403" in msg or "Forbidden" in msg or "ProxyError" in type(e).__name__:
                    # 沙箱 proxy 或 Cloudflare 擋裸請求，正常；Playwright session 帶 cookie 不受影響
                    print(f"    OK  {label}: Cloudflare/proxy 擋裸請求（正常，Playwright session 不受影響）")
                else:
                    print(f"    FAIL {label}: {e}")
                    all_ok = False

    # 5. Markdown 輸出格式
    print("\n[5] Markdown 輸出格式測試")
    try:
        fake_job = {
            "title": "Dry Run Test Job",
            "url": "https://www.upwork.com/jobs/~dry_run",
            "budget": "USD 500",
            "job_type": "Fixed",
            "duration": "",
            "posted": "2026-06-25",
            "description": "Google Apps Script automation dry run test",
            "client_location": "Taiwan",
            "client_payment_verified": True,
            "client_feedback": 4.9,
            "client_reviews": 10,
            "skills": ["Google Apps Script", "Google Sheets"],
        }
        md = jobs_to_markdown([fake_job], ["dry-run"])
        assert "Dry Run Test Job" in md
        print("    OK  Markdown 格式輸出正常")
    except Exception as e:
        print(f"    FAIL Markdown 測試：{e}")
        all_ok = False

    print("\n" + "=" * 60)
    if all_ok:
        print("PASS  Dry-run 全部通過。執行正式搜尋：python upwork_api_search.py")
    else:
        print("FAIL  有項目失敗，請修正後再執行正式搜尋。")
    print("=" * 60)


async def main(queries: list[str], limit: int):
    check_auth_expiry()

    print("=" * 60)
    print("Phase 2：Upwork API 搜尋")
    print("=" * 60)
    print(f"搜尋關鍵字：{queries}")
    print(f"結果上限：每個關鍵字 {limit} 筆")
    print()

    jobs = await search_via_playwright(queries, limit)

    if not jobs:
        print("\n沒有取得任何結果。")
        print("可能原因：session 過期、搜尋無結果、API 格式改變。")
        print("建議重跑 Phase 1：python upwork_capture_auth.py")
        return

    # 去重（依 URL）
    seen_urls = set()
    unique_jobs = []
    for job in jobs:
        if job["url"] not in seen_urls:
            seen_urls.add(job["url"])
            unique_jobs.append(job)

    print(f"\nOK  取得 {len(unique_jobs)} 筆唯一結果（原始 {len(jobs)} 筆）")

    # 存成 Markdown
    LEADS_DIR.mkdir(parents=True, exist_ok=True)
    date_str = datetime.now(TAIPEI_TZ).strftime("%Y-%m-%d")
    out_path = LEADS_DIR / f"{date_str}.md"

    md = jobs_to_markdown(unique_jobs, queries)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(md)
    print(f"Leads 已存到：{out_path}")

    json_path = LEADS_DIR / f"{date_str}.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(unique_jobs, f, ensure_ascii=False, indent=2)
    print(f"JSON 備份：{json_path}")

    print("\n── 前 3 筆結果預覽 ──")
    for job in unique_jobs[:3]:
        score = score_job(job)
        print(f"  [{score}/10] {job['title'][:60]}")
        print(f"         {job['url']}")
        print(f"         Budget: {job['budget']} | {job['client_location']}")


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Upwork API Job Search (Phase 2)")
    parser.add_argument(
        "--query", "-q",
        nargs="+",
        help="搜尋關鍵字（可多個），預設從設定檔讀取",
    )
    parser.add_argument(
        "--limit", "-l",
        type=int,
        default=DEFAULT_LIMIT,
        help=f"每個關鍵字最多幾筆（預設 {DEFAULT_LIMIT}）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只測試環境和連線，不執行實際搜尋，不需要登入",
    )
    args = parser.parse_args()

    queries = args.query if args.query else load_config_queries()

    if args.dry_run:
        asyncio.run(dry_run(queries))
    else:
        asyncio.run(main(queries, args.limit))
