"""Deterministically compare a knowledge candidate with the local pool."""

from __future__ import annotations

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path


STOP_WORDS = {
    "agentos", "boundary", "claude", "codex", "dispatch", "external",
    "false", "knowledge", "links", "media", "pipeline", "points",
    "result", "source", "summary", "true", "untrusted", "url",
    "內容", "來源", "結果", "摘要", "知識", "連結", "外部",
}


def semantic_text(text: str) -> str:
    sections = []
    for heading in (
        "Summary", "Key Points", "AgentOS Value", "Original Source", "Codex Analysis"
    ):
        match = re.search(
            rf"(?ms)^##\s+{re.escape(heading)}\s*\r?\n(.+?)(?=^##\s+|\Z)", text
        )
        if match:
            sections.append(match.group(1))
    return "\n".join(sections) if sections else text


def tokens(text: str) -> Counter[str]:
    text = semantic_text(text).lower()
    result: list[str] = []
    for word in re.findall(r"[a-z][a-z0-9_.-]{2,}", text):
        if word not in STOP_WORDS and not word.startswith(("http", "e:", "c:")):
            result.append(word)
    for run in re.findall(r"[\u3400-\u9fff]{2,}", text):
        for index in range(len(run) - 1):
            token = run[index : index + 2]
            if token not in STOP_WORDS:
                result.append(token)
    return Counter(result)


def cosine(left: Counter[str], right: Counter[str]) -> float:
    if not left or not right:
        return 0.0
    common = set(left).intersection(right)
    numerator = sum(left[item] * right[item] for item in common)
    left_norm = math.sqrt(sum(value * value for value in left.values()))
    right_norm = math.sqrt(sum(value * value for value in right.values()))
    return numerator / (left_norm * right_norm) if left_norm and right_norm else 0.0


def analyze(
    candidate: Path,
    pool: Path,
    exclude: Path | None,
    threshold: float,
    system_root: Path | None = None,
    system_threshold: float = 0.055,
) -> dict[str, object]:
    candidate_tokens = tokens(candidate.read_text(encoding="utf-8"))
    scored: list[dict[str, object]] = []
    candidates: list[tuple[Path, str]] = []
    if pool.is_dir():
        for path in pool.glob("*.md"):
            if exclude and path.resolve() == exclude.resolve():
                continue
            candidates.append((path, "knowledge_node"))
    if system_root and system_root.is_dir():
        for relative in ("AGENTS.md", "current_state.md", "docs/ARCHITECTURE.md"):
            path = system_root / relative
            if path.is_file():
                candidates.append((path, "system_reference"))
        decisions = system_root / "docs" / "decisions"
        if decisions.is_dir():
            candidates.extend((path, "system_reference") for path in decisions.glob("*.md"))
    seen: set[Path] = set()
    for path, kind in candidates:
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        try:
            score = cosine(candidate_tokens, tokens(path.read_text(encoding="utf-8")))
        except (OSError, UnicodeError):
            continue
        if score > 0:
            scored.append({"path": str(resolved), "kind": kind, "score": round(score, 4)})
    scored.sort(key=lambda item: float(item["score"]), reverse=True)
    related = [
        item for item in scored
        if float(item["score"]) >= (
            system_threshold if item["kind"] == "system_reference" else threshold
        )
    ][:3]
    top_score = float(related[0]["score"]) if related else (float(scored[0]["score"]) if scored else 0.0)
    return {
        "schema_version": 1,
        "method": "local_cosine_en_words_zh_bigrams_v1",
        "knowledge_relation": "related" if related else "new_node",
        "relation_confidence": round(top_score, 4),
        "knowledge_similarity_threshold": threshold,
        "system_similarity_threshold": system_threshold,
        "related_nodes": related,
        "top_candidates": scored[:5],
        "candidate_token_count": sum(candidate_tokens.values()),
        "external_models_invoked": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate-result", required=True)
    parser.add_argument("--knowledge-pool", required=True)
    parser.add_argument("--exclude")
    parser.add_argument("--system-root")
    parser.add_argument("--output", required=True)
    parser.add_argument("--threshold", type=float, default=0.13)
    parser.add_argument("--system-threshold", type=float, default=0.055)
    args = parser.parse_args()
    result = analyze(
        Path(args.candidate_result),
        Path(args.knowledge_pool),
        Path(args.exclude) if args.exclude else None,
        args.threshold,
        Path(args.system_root) if args.system_root else None,
        args.system_threshold,
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"knowledge_relation={result['knowledge_relation']}")
    print(f"relation_confidence={result['relation_confidence']}")
    print(f"relation_artifact={output.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
