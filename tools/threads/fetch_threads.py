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

        post_code_match = re.search(r"/post/([A-Za-z0-9_-]+)", urlparse(url).path)
        post_code = post_code_match.group(1) if post_code_match else ""

        extracted = await page.evaluate(
            """
            (postCode) => {
                const INTERNAL_HOSTS = /(^|\\.)(threads\\.com|threads\\.net|instagram\\.com|facebook\\.com|meta\\.com)$/i;

                const unwrapLink = (href) => {
                    try {
                        const u = new URL(href);
                        // Threads wraps external links: l.threads.com/l.php?u=<encoded>
                        if (/^l\\.(threads|instagram|facebook)\\.(com|net)$/i.test(u.hostname)) {
                            const target = u.searchParams.get('u');
                            if (target) return target;
                        }
                        return href;
                    } catch { return null; }
                };

                const authorOf = (article) => {
                    const a = article.querySelector('a[href^="/@"]');
                    if (!a) return '';
                    const m = a.getAttribute('href').match(/^\\/(@[^/?#]+)/);
                    return m ? m[1] : '';
                };

                const collect = (container) => {
                    const text = container.innerText?.trim() || '';
                    const images = [...container.querySelectorAll('img')]
                        .map((img) => img.src)
                        .filter((src) =>
                            src &&
                            src.startsWith('https://') &&
                            !/emoji|icon|avatar|profile/i.test(src)
                        );
                    const posters = [...container.querySelectorAll('video[poster]')]
                        .map((video) => video.poster)
                        .filter((src) => src && src.startsWith('https://'));
                    const links = [...container.querySelectorAll('a[href]')]
                        .map((a) => ({ url: unwrapLink(a.href), text: (a.innerText || '').trim() }))
                        .filter((l) => {
                            if (!l.url || !/^https?:/i.test(l.url)) return false;
                            try { return !INTERNAL_HOSTS.test(new URL(l.url).hostname); }
                            catch { return false; }
                        });
                    return { text, images: [...images, ...posters], links };
                };

                const articles = [...document.querySelectorAll('article')];
                if (articles.length === 0) {
                    const container =
                        document.querySelector('[data-pressable-container]') ||
                        document.querySelector('main');
                    if (!container) {
                        return { text: document.title || '', images: [], links: [], posts: [] };
                    }
                    const single = collect(container);
                    return { ...single, posts: [{ author: '', text: single.text }] };
                }

                // 1. Anchor on the focused post: the article whose permalink
                //    contains the post code from the requested URL. Everything
                //    rendered ABOVE it is its ancestor chain (Threads shows no
                //    unrelated articles before the focused post).
                let focusedIdx = postCode
                    ? articles.findIndex((a) =>
                          a.querySelector('a[href*="/post/' + postCode + '"]'))
                    : -1;
                const anchor_found = focusedIdx !== -1;
                if (focusedIdx === -1) focusedIdx = 0;

                // 2. Primary author = author of the FOCUSED post (the one Josh
                //    sent), not whatever renders first.
                const primaryAuthor = authorOf(articles[focusedIdx]);

                // 3. Cut off suggestion sections ("更多來自 X 的串文" / "More
                //    from X"): same author but a DIFFERENT thread — exclude
                //    every article after that boundary.
                const boundary = [...document.querySelectorAll('span, h2, h3, [role="heading"]')]
                    .find((el) => {
                        const t = (el.innerText || '').trim();
                        return t.length > 0 && t.length < 80 &&
                            /(更多來自|More from)/i.test(t);
                    });
                const afterBoundary = (article) =>
                    boundary &&
                    (boundary.compareDocumentPosition(article) & Node.DOCUMENT_POSITION_FOLLOWING);

                const kept = articles.filter((article, idx) => {
                    if (afterBoundary(article)) return false;
                    if (idx === focusedIdx) return true;           // always keep target post
                    if (idx < focusedIdx) return true;             // ancestor chain (context)
                    // below the focused post: keep only the author's own
                    // self-replies; other users' replies are noise.
                    return primaryAuthor && authorOf(article) === primaryAuthor;
                });

                const posts = [];
                const images = [];
                const links = [];
                for (const article of kept) {
                    const c = collect(article);
                    posts.push({ author: authorOf(article), text: c.text });
                    images.push(...c.images);
                    links.push(...c.links);
                }

                const seen = new Set();
                const uniqueLinks = links.filter((l) => {
                    if (seen.has(l.url)) return false;
                    seen.add(l.url);
                    return true;
                });

                return {
                    text: posts.map((p) => p.text).join('\\n\\n---\\n\\n'),
                    images: [...new Set(images)],
                    links: uniqueLinks,
                    posts,
                    anchor_found,
                };
            }
            """,
            post_code,
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
        "links": extracted.get("links", []),
        "post_count": len(extracted.get("posts", [])),
        "anchor_found": bool(extracted.get("anchor_found", False)),
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
            "links": [],
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
