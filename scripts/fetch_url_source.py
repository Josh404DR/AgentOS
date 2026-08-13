"""Fetch a public HTTP(S) document as untrusted data for AgentOS URL intake."""

from __future__ import annotations

import argparse
import html
import ipaddress
import json
import socket
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path


MAX_REDIRECTS = 5
SUPPORTED_TEXT_TYPES = (
    "text/",
    "application/json",
    "application/xml",
    "application/xhtml+xml",
    "application/rss+xml",
    "application/atom+xml",
)


def validate_public_url(url: str) -> None:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise ValueError("unsupported_url_scheme")
    if not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("invalid_url_authority")
    hostname = parsed.hostname.rstrip(".").lower()
    if hostname == "localhost" or hostname.endswith(".localhost") or hostname.endswith(".local"):
        raise ValueError("local_hostname_blocked")
    port = parsed.port or (443 if parsed.scheme.lower() == "https" else 80)
    addresses = {item[4][0] for item in socket.getaddrinfo(hostname, port, type=socket.SOCK_STREAM)}
    if not addresses:
        raise ValueError("hostname_resolution_empty")
    for address in addresses:
        ip = ipaddress.ip_address(address.split("%")[0])
        if not ip.is_global:
            raise ValueError("non_public_address_blocked")


class SafeRedirectHandler(urllib.request.HTTPRedirectHandler):
    def __init__(self) -> None:
        super().__init__()
        self.redirect_count = 0

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: ANN001
        self.redirect_count += 1
        if self.redirect_count > MAX_REDIRECTS:
            raise urllib.error.HTTPError(newurl, code, "too_many_redirects", headers, fp)
        target = urllib.parse.urljoin(req.full_url, newurl)
        validate_public_url(target)
        return super().redirect_request(req, fp, code, msg, headers, target)


class DocumentParser(HTMLParser):
    def __init__(self, base_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.skip_depth = 0
        self.title_depth = 0
        self.title_parts: list[str] = []
        self.text_parts: list[str] = []
        self.links: list[dict[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "svg", "template"}:
            self.skip_depth += 1
            return
        if self.skip_depth:
            return
        if tag == "title":
            self.title_depth += 1
        if tag == "a":
            href = dict(attrs).get("href")
            if href and len(self.links) < 100:
                absolute = urllib.parse.urljoin(self.base_url, href)
                if urllib.parse.urlsplit(absolute).scheme.lower() in {"http", "https"}:
                    self.links.append({"url": absolute, "text": ""})
        if tag in {"p", "br", "div", "article", "section", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.text_parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"script", "style", "noscript", "svg", "template"} and self.skip_depth:
            self.skip_depth -= 1
            return
        if tag == "title" and self.title_depth:
            self.title_depth -= 1

    def handle_data(self, data: str) -> None:
        if self.skip_depth:
            return
        value = " ".join(html.unescape(data).split())
        if not value:
            return
        if self.title_depth:
            self.title_parts.append(value)
        self.text_parts.append(value)


def normalize_text(parts: list[str], limit: int = 50_000) -> str:
    lines = []
    for line in " ".join(parts).replace(" \n ", "\n").splitlines():
        clean = " ".join(line.split())
        if clean and (not lines or lines[-1] != clean):
            lines.append(clean)
    value = "\n".join(lines).strip()
    return value[:limit]


def extract_document(raw: bytes, content_type: str, final_url: str, charset: str | None) -> tuple[str, str, list[dict[str, str]]]:
    encoding = charset or "utf-8"
    try:
        decoded = raw.decode(encoding, errors="replace")
    except LookupError:
        decoded = raw.decode("utf-8", errors="replace")
    if "html" not in content_type.lower():
        return "", normalize_text([decoded]), []
    parser = DocumentParser(final_url)
    parser.feed(decoded)
    return normalize_text(parser.title_parts, 500), normalize_text(parser.text_parts), parser.links


def fetch(url: str, max_bytes: int, timeout: int) -> dict[str, object]:
    payload: dict[str, object] = {
        "fetch_status": "failed",
        "source_untrusted": True,
        "url": url,
        "final_url": "",
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "status_code": None,
        "content_type": "",
        "title": "",
        "text": "",
        "links": [],
        "images": [],
        "screenshot": "",
        "error": "",
    }
    try:
        validate_public_url(url)
        opener = urllib.request.build_opener(SafeRedirectHandler())
        request = urllib.request.Request(
            url,
            headers={"User-Agent": "AgentOS-Knowledge-Intake/1.0 (+local governed fetcher)"},
        )
        with opener.open(request, timeout=timeout) as response:
            final_url = response.geturl()
            validate_public_url(final_url)
            content_type = response.headers.get_content_type().lower()
            if not any(content_type.startswith(item) for item in SUPPORTED_TEXT_TYPES):
                raise ValueError("unsupported_content_type")
            declared_length = response.headers.get("Content-Length")
            if declared_length and int(declared_length) > max_bytes:
                raise ValueError("content_too_large")
            raw = response.read(max_bytes + 1)
            if len(raw) > max_bytes:
                raise ValueError("content_too_large")
            title, text, links = extract_document(
                raw, content_type, final_url, response.headers.get_content_charset()
            )
            if not text:
                raise ValueError("no_extractable_text")
            payload.update(
                fetch_status="success",
                final_url=final_url,
                status_code=getattr(response, "status", 200),
                content_type=content_type,
                title=title,
                text=text,
                links=links,
            )
    except Exception as exc:  # Evidence artifact must exist even on fetch failure.
        payload["error"] = f"{type(exc).__name__}:{exc}"
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--max-bytes", type=int, default=2_000_000)
    args = parser.parse_args()
    result = fetch(args.url, args.max_bytes, args.timeout)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"fetch_status={result['fetch_status']}")
    print(f"source_json_path={output.resolve()}")
    if result["error"]:
        print(f"source_error={result['error']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
