from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path


def field(text: str, name: str) -> str:
    match = re.search(rf"(?mi)^{re.escape(name)}\s*[:=]\s*(.+?)\s*$", text)
    return match.group(1).strip().strip("\"'") if match else ""


def write_if_changed(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text(encoding="utf-8", errors="replace") == content:
        return False
    path.write_text(content, encoding="utf-8")
    return True


def safe_name(value: str, fallback: str) -> str:
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "-", value).strip(" .-")
    return cleaned[:100] or fallback


def task_status(task: str, result: str) -> str:
    combined = f"{task}\n{result}"
    if re.search(
        r"(?mi)^(?:task_status|pipeline_status|status|codex_execution_status)"
        r"\s*[:=]\s*(?:blocked|failed)\s*$",
        combined,
    ):
        return "受阻"
    if result:
        return "已完成"
    if re.search(
        r"(?mi)^(?:task_status|pipeline_status)\s*[:=]\s*processing\s*$",
        combined,
    ):
        return "進行中"
    return "待處理"


def short_task_name(dispatch_id: str, task_dir_name: str) -> str:
    match = re.search(r"telegram-telegram-\d+-(\d+)-", dispatch_id)
    if match:
        return f"TG-{match.group(1)}"
    compact = re.sub(r"[^A-Za-z0-9_-]+", "-", dispatch_id).strip("-")
    return compact[-28:] or task_dir_name[-28:]


PROJECT_RULES: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("Obsidian 宇宙", ("obsidian", "工單宇宙", "語意宇宙", "graph view")),
    ("共同治理", ("agents.md", "governance", "共同治理", "治理基線")),
    ("Knowledge Pool", ("knowledge_pool", "knowledge pool", "知識節點")),
    ("NotebookLM", ("notebooklm", "notebook llm", "bundle")),
    ("Telegram Intake", ("telegram", "threads intake", "url intake", "typed dispatch")),
    ("Hermes Gateway", ("hermes", "gateway", "groq", "openrouter")),
    ("Dashboard", ("dashboard", "fastapi", "next.js", "前端", "監控平台")),
)


def classify_project(task_dir_name: str, task: str, result: str) -> tuple[str, str]:
    explicit_project = field(task, "project_id")
    if explicit_project:
        return explicit_project, "explicit:project_id"
    if "url-intake" in task_dir_name.lower():
        return "Knowledge Pool", "task_type:url-intake"
    evidence = f"{task_dir_name}\n{task}\n{result}".lower()
    scores: list[tuple[int, int, str, list[str]]] = []
    for order, (project, keywords) in enumerate(PROJECT_RULES):
        matched = [keyword for keyword in keywords if keyword.lower() in evidence]
        # Telegram appears in transport metadata for nearly every packet. Treat it
        # as a fallback route, not a stronger semantic project assignment.
        if project == "Telegram Intake":
            continue
        scores.append((len(matched), -order, project, matched))
    score, _, project, matched = max(scores)
    if score == 0:
        telegram_keywords = dict(PROJECT_RULES)["Telegram Intake"]
        telegram_matched = [
            keyword for keyword in telegram_keywords if keyword.lower() in evidence
        ]
        if telegram_matched:
            return "Telegram Intake", "fallback_keywords:" + ",".join(telegram_matched)
        return "AgentOS 核心", "fallback:no_keyword_match"
    return project, "keywords:" + ",".join(matched)


def changed_files(result: str) -> list[str]:
    paths: list[str] = []
    in_section = False
    for line in result.splitlines():
        if re.match(
            r"(?i)^(?:#{1,4}\s*)?(files changed|changed files|實際變更)\s*:",
            line,
        ):
            in_section = True
            continue
        if in_section and (
            line.startswith("#")
            or re.match(r"(?i)^[A-Za-z][A-Za-z ]{2,30}:\s*$", line)
        ):
            break
        if not in_section:
            continue
        match = re.match(r"^\s*-\s+`?([^`]+?)`?\s*$", line)
        if match:
            candidate = match.group(1).strip()
            if any(sep in candidate for sep in ("\\", "/")) or "." in Path(candidate).name:
                paths.append(candidate)
    return list(dict.fromkeys(paths))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=r"E:\AgentOS")
    parser.add_argument("--recent-days", type=int, default=2)
    args = parser.parse_args()

    root = Path(args.root).resolve()
    vault = root / "exports" / "obsidian_agentos"
    task_root = root / "data" / "codex_tasks"
    knowledge_root = root / "data" / "knowledge_pool"
    folders = {
        name: vault / name
        for name in ("視圖節點", "專案", "決策", "產物", "知識", "狀態", "角色")
    }
    for folder in folders.values():
        folder.mkdir(parents=True, exist_ok=True)

    task_dirs = sorted(
        (p for p in task_root.iterdir() if p.is_dir() and (p / "TASK.md").is_file()),
        key=lambda p: p.name,
        reverse=True,
    )
    recent_dates: list[str] = []
    for task_dir in task_dirs:
        match = re.match(r"^(\d{4}-\d{2}-\d{2})", task_dir.name)
        if match and match.group(1) not in recent_dates:
            recent_dates.append(match.group(1))
        if len(recent_dates) == args.recent_days:
            break

    written = 0
    project_tasks: dict[str, list[str]] = {}
    project_evidence: dict[str, list[str]] = {}
    artifact_links: list[str] = []
    for task_dir in task_dirs:
        if recent_dates and not any(task_dir.name.startswith(day) for day in recent_dates):
            continue
        task = (task_dir / "TASK.md").read_text(encoding="utf-8", errors="replace")
        result_path = task_dir / "OUTPUTS" / "RESULT.md"
        result = result_path.read_text(encoding="utf-8", errors="replace") if result_path.is_file() else ""
        dispatch_id = field(task, "dispatch_id") or task_dir.name
        route = field(task, "route_to") or field(task, "assigned_to") or "未知"
        governance_version = field(task, "governance_version") or "legacy"
        status = task_status(task, result)
        short_name = short_task_name(dispatch_id, task_dir.name)
        project, classification_evidence = classify_project(task_dir.name, task, result)
        project_tasks.setdefault(project, []).append(f"[[視圖節點/{short_name}]]")
        project_evidence.setdefault(project, []).append(
            f"`{short_name}` ← `{classification_evidence}`"
        )
        view = f"""---
type: agentos-universe-view
node_type: task
project_id: "{project}"
dispatch_id: "{dispatch_id}"
status: "{status}"
route_to: "{route}"
relation_type:
  - belongs_to
  - routed_to
source_path: "{task_dir / "TASK.md"}"
generated_read_only: true
---

# {short_name}

- 對應工單：[[工單/{task_dir.name}|{dispatch_id}]]
- 所屬專案：[[專案/{project}]]
- 狀態：[[狀態/{status}]]
- 路由：[[角色/{route}]]
- 治理：[[共同治理 v{governance_version}]]
- 分類證據：`{classification_evidence}`
"""
        written += int(write_if_changed(folders["視圖節點"] / f"{short_name}.md", view))

        for raw_path in changed_files(result):
            artifact_id = hashlib.sha256(raw_path.lower().encode("utf-8")).hexdigest()[:10]
            artifact_name = safe_name(Path(raw_path).name, artifact_id)
            note_name = f"{artifact_name}-{artifact_id}"
            artifact_links.append(f"[[產物/{note_name}]]")
            artifact = f"""---
type: agentos-artifact
node_type: artifact
project_id: "{project}"
artifact_path: "{raw_path.replace('"', '""')}"
source_dispatch_id: "{dispatch_id}"
relation_type:
  - produced_by
  - belongs_to
source_path: "{result_path}"
generated_read_only: true
---

# 產物：{artifact_name}

- 產出自：[[視圖節點/{short_name}]]
- 所屬專案：[[專案/{project}]]
- 實際路徑：`{raw_path}`
- 證據：`{result_path}`
"""
            written += int(write_if_changed(folders["產物"] / f"{note_name}.md", artifact))

    knowledge_links: list[str] = []
    if knowledge_root.is_dir():
        for source in sorted(knowledge_root.glob("*.md")):
            text = source.read_text(encoding="utf-8", errors="replace")
            title_match = re.search(r"(?m)^#\s+(.+)$", text)
            title = title_match.group(1).strip() if title_match else source.stem
            dispatch_id = field(text, "dispatch_id") or "legacy_unlinked"
            canonical_url = field(text, "canonical_url") or field(text, "source_url") or "not_available"
            sync_status = field(text, "notebooklm_sync_status") or "unknown"
            node_name = safe_name(source.stem, "knowledge")
            knowledge_links.append(f"[[知識/{node_name}]]")
            node = f"""---
type: agentos-knowledge
node_type: knowledge
project_id: "Knowledge Pool"
dispatch_id: "{dispatch_id}"
notebooklm_sync_status: "{sync_status}"
relation_type:
  - belongs_to
  - published_to
source_path: "{source}"
generated_read_only: true
---

# 知識：{title}

- 所屬專案：[[專案/Knowledge Pool]]
- 來源節點：`{source}`
- 原文網址：{canonical_url}
- NotebookLM 狀態：`{sync_status}`
- 關係規則：同內容不同工單仍保留為獨立節點。
"""
            written += int(write_if_changed(folders["知識"] / f"{node_name}.md", node))

    decisions = {
        "共同治理採版本與雜湊握手": (
            "治理規則由 `E:\\AgentOS\\AGENTS.md` 統一，執行前必須通過 fail-closed 閘門。",
            "E:\\AgentOS\\AGENTS.md",
        ),
        "Knowledge Pool 與五個 Bundle 分離": (
            "Knowledge Pool 節點獨立同步 NotebookLM，不併入五個固定 bundles。",
            "E:\\AgentOS\\AGENTS.md",
        ),
        "Obsidian 僅作唯讀導航層": (
            "AgentOS 工單與 RESULT 是 source of truth；Obsidian 不反向覆寫。",
            str(root / "exports" / "obsidian_agentos"),
        ),
    }
    decision_links: list[str] = []
    for title, (summary, evidence) in decisions.items():
        node_name = safe_name(title, "decision")
        decision_links.append(f"[[決策/{node_name}]]")
        content = f"""---
type: agentos-decision
node_type: decision
project_id: "共同治理"
owner: "Josh"
relation_type:
  - governs
  - belongs_to
source_path: "{evidence}"
generated_read_only: true
---

# 決策：{title}

{summary}

- 所屬專案：[[專案/共同治理]]
- 證據：`{evidence}`
"""
        written += int(write_if_changed(folders["決策"] / f"{node_name}.md", content))

    project_tasks.setdefault("Knowledge Pool", [])
    project_tasks.setdefault("共同治理", [])
    project_links: list[str] = []
    for project_name in sorted(project_tasks):
        project_links.append(f"[[專案/{project_name}]]")
        task_lines = project_tasks[project_name]
        extra = ""
        if project_name == "Knowledge Pool":
            extra = "\n## 知識節點\n\n" + (
                "\n".join(f"- {link}" for link in knowledge_links) or "- 尚無"
            )
        if project_name == "共同治理":
            extra += "\n## 治理決策\n\n" + "\n".join(
                f"- {link}" for link in decision_links
            )
        moc = f"""---
type: agentos-project
node_type: project
project_id: "{project_name}"
project_status: active
owner: Josh
relation_type:
  - contains
source_path: "{root}"
generated_read_only: true
---

# 專案：{project_name}

> 本頁是專案 MOC；原始 TASK／RESULT 才是唯一事實來源。

## 最近工單

{chr(10).join(f"- {link}" for link in task_lines) or "- 目前兩個工作日期內沒有工單"}

## 自動分類證據

{chr(10).join(f"- {item}" for item in project_evidence.get(project_name, [])) or "- 無"}
{extra}
"""
        written += int(
            write_if_changed(folders["專案"] / f"{project_name}.md", moc)
        )

    universe = f"""---
type: agentos-universe-index
node_type: universe
generated_read_only: true
---

# AgentOS 總宇宙

日常請先進入一個專案星系，再開啟 Local Graph（深度 1–2）。

## 專案星系

{chr(10).join(f"- {link}" for link in project_links)}

## 使用原則

- 全域圖：觀察跨專案關係與治理污染。
- 專案 MOC：日常導航與進度入口。
- 原始工單：`{task_root}`。
- 本 Vault：唯讀衍生層，不反向覆寫 AgentOS。
"""
    written += int(write_if_changed(vault / "AgentOS 總宇宙.md", universe))
    legacy_governance = """---
type: agentos-governance-reference
historical: true
generated_read_only: true
---

# 共同治理 vlegacy

此節點表示工單建立時尚未綁定 `governance_version`，不能據此宣稱符合目前治理。

- 現行治理：[[共同治理 v1.1.0]]
- 狀態意義：歷史工單／缺少治理綁定
"""
    written += int(write_if_changed(vault / "共同治理 vlegacy.md", legacy_governance))
    legacy_redirect = """---
type: agentos-redirect
historical: true
generated_read_only: true
---

# AgentOS（舊入口）

此頁已由單一中心改為分散式專案星系，請改從 [[AgentOS 總宇宙]] 進入。
"""
    written += int(write_if_changed(folders["專案"] / "AgentOS.md", legacy_redirect))

    print("obsidian_universe_export_status=completed")
    print(f"recent_dates={','.join(recent_dates)}")
    print(f"view_nodes={sum(len(items) for items in project_tasks.values())}")
    print(f"project_nodes={len(project_tasks)}")
    print(f"artifact_nodes={len(set(artifact_links))}")
    print(f"knowledge_nodes={len(knowledge_links)}")
    print(f"decision_nodes={len(decision_links)}")
    print(f"files_written={written}")
    print(f"vault={vault}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
