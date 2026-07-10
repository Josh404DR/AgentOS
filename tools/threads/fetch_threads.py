"""Fetch a public Threads post into an auditable per-dispatch directory."""

from __future__ import annotations

import argparse
import asyncio
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

from playwright.async_api import async_playwright

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


ALLOWED_HOSTS = {
    "threads.com",
    "www.threads.com",
    "threads.net",
    "www.threads.net",
}
MAX_IMAGES = 12


def validate_threads_url(raw_url: str) -> str:
    parsed = urlparse(raw_url)
    if parsed.scheme.lower() != "https":
        raise ValueError("Only HTTPS Threads URLs are allowed.")
    if (parsed.hostname or "").lower() not in ALLOWED_HOSTS:
        raise ValueError(f"Unsupported Threads hostname: {parsed.hostname}")
    return raw_url


def safe_extension(content_type: str, url: str) -> str:
    content_type = (content_type or "").lower()
    if "png" in content_type or ".png" in url.lower():
        return "png"
    if "webp" in content_type or ".webp" in url.lower():
        return "webp"
    if "gif" in content_type or ".gif" in url.lower():
        return "gif"
    return "jpg"


async def fetch_post(url: str, output_dir: Path, headed: bool) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    image_dir = output_dir / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    screenshot_path = output_dir / "screenshot.png"

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(
            headless=not headed,
            channel="chrome",
            args=["--no-sandbox"],
        )
        page = await browser.new_page(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            )
        )

        response = await page.goto(url, wait_until="domcontentloaded", timeout=45_000)
        final_url = validate_threads_url(page.url)
        await page.wait_for_timeout(4_000)
        await page.screenshot(path=str(screenshot_path), full_page=False)

        extracted = await page.evaluate(
            """
            () => {
                const container =
                    document.querySelector('article') ||
                    document.querySelector('[data-pressable-container]') ||
                    document.querySelector('main');
                const text = container?.innerText?.trim() || document.title || '';
                if (!container) return { text, images: [] };
                const imageUrls = [...container.querySelectorAll('img')]
                    .map((img) => img.src)
                    .filter((src) =>
                        src &&
                        src.startsWith('https://') &&
                        !/emoji|icon|avatar|profile/i.test(src)
                    );
                const posters = [...container.querySelectorAll('video[poster]')]
                    .map((video) => video.poster)
                    .filter((src) => src && src.startsWith('https://'));
                return { text, images: [...new Set([...imageUrls, ...posters])] };
            }
            """
        )

        image_paths: list[str] = []
        for index, image_url in enumerate(extracted["images"][:MAX_IMAGES], start=1):
            try:
                image_response = await page.request.get(image_url, timeout=15_000)
                if not image_response.ok:
                    continue
                data = await image_response.body()
                if len(data) <= 5_000:
                    continue
                extension = safe_extension(
                    image_response.headers.get("content-type", ""),
                    image_url,
                )
                image_path = image_dir / f"image_{index:02d}.{extension}"
                image_path.write_bytes(data)
                image_paths.append(str(image_path.resolve()))
            except Exception:
                continue

        status_code = response.status if response else None
        await browser.close()

    text = re.sub(r"\n{3,}", "\n\n", extracted["text"]).strip()
    if not text:
        raise RuntimeError("Threads page loaded but no post text was extracted.")

    return {
        "fetch_status": "success",
        "url": url,
        "final_url": final_url,
        "http_status": status_code,
        "text": text,
        "images": image_paths,
        "screenshot": str(screenshot_path.resolve()),
        "source_untrusted": True,
    }


async def async_main(args: argparse.Namespace) -> int:
    output_dir = Path(args.output_dir).resolve()
    try:
        url = validate_threads_url(args.url)
        result = await fetch_post(url, output_dir, args.headed)
        exit_code = 0
    except Exception as exc:
        result = {
            "fetch_status": "failed",
            "url": args.url,
            "text": "",
            "images": [],
            "screenshot": "",
            "source_untrusted": True,
            "error": f"{type(exc).__name__}: {exc}",
        }
        exit_code = 1

    source_path = output_dir / "source.json"
    output_dir.mkdir(parents=True, exist_ok=True)
    source_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print("[RESULT_JSON]")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    print("[/RESULT_JSON]")
    print(f"source_json_path={source_path}")
    return exit_code


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch a public Threads post.")
    parser.add_argument("url", help="Public threads.com or threads.net URL.")
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Per-dispatch output directory for source.json, images, and screenshot.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Show Chrome for interactive debugging. Headless is the default.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    sys.exit(asyncio.run(async_main(parse_args())))
