import json
import os
import sys
import time
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.hermes_lite_knowledge.indexer import SOURCE_TYPES, Indexer, discover, query_index


def write(root: Path, relative: str, content: str = "content") -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


@pytest.fixture
def source_tree(tmp_path):
    samples = {
        "data/codex_tasks/t1/TASK.md": "# Task\ndispatch_id: alpha",
        "data/codex_tasks/t1/PROMPT_FOR_CODEX.md": "prompt",
        "data/codex_tasks/t1/STATUS.md": "status",
        "data/codex_tasks/t1/OUTPUTS/RESULT.md": "result",
        "data/codex_tasks/t1/OUTPUTS/TEST_RESULT.md": "test",
        "data/codex_tasks/t1/OUTPUTS/VERIFY_BUNDLE.md": "bundle",
        "data/codex_tasks/t1/OUTPUTS/VERIFY_RESULT.md": "verdict",
        "data/codex_tasks/t1/OUTPUTS/DELIVERY.md": "delivery",
        "data/escalations/e1/EVENT.json": '{"event":"open"}',
        "data/escalations/e1/RESOLUTION.json": '{"status":"closed"}',
        "data/escalations/e1/DECISION-1.json": '{"choice":"yes"}',
        "data/learning_candidates/LC-1.json": '{"topic":"x"}',
        "data/metrics/METRICS_LOG.jsonl": '{"model_calls":0}\n',
        "docs/guide.md": "# Guide",
        "current_state.md": "# State",
        "AGENTS.md": "# Governance",
        "docs/PROJECT_TASK_BOARD_2026-08-10.md": "# Board",
    }
    for path, content in samples.items():
        write(tmp_path, path, content)
    return tmp_path


def test_all_17_source_types(source_tree):
    kinds = {kind for _, kind in discover(source_tree).values()}
    assert kinds == set(SOURCE_TYPES)


@pytest.mark.parametrize("relative", [
    "data/dashboard_auth/secret.json", ".env", "x.env", "archive/old.md",
    "AgentOS_export-test.zip", "logs/runtime.log",
    "data/codex_tasks/t1/OUTPUTS/CODEX_CONSOLE.log",
    "data/escalations/ESCALATION_INDEX.jsonl", "docs/decisions/_layout.json",
])
def test_explicit_exclusions(tmp_path, relative):
    write(tmp_path, relative, "{}")
    assert relative not in discover(tmp_path)


def test_full_incremental_add_change_delete_and_query(source_tree, tmp_path):
    state = tmp_path / "state.json"
    indexer = Indexer(source_tree, state)
    first = indexer.run()
    assert first.mode == "full" and len(first.added) == 17
    second = indexer.run()
    assert second.mode == "incremental" and second.unchanged == 17
    added = write(source_tree, "docs/new.md", "# New Topic\nZEBRA")
    third = indexer.run()
    assert "docs/new.md" in third.added
    time.sleep(0.002)
    added.write_text("# Changed Topic", encoding="utf-8")
    os.utime(added, None)
    fourth = indexer.run()
    assert "docs/new.md" in fourth.changed
    added.unlink()
    fifth = indexer.run()
    assert "docs/new.md" in fifth.deleted
    assert query_index(state, "alpha")[0]["path"] == "data/codex_tasks/t1/TASK.md"
    entry = json.loads(state.read_text(encoding="utf-8"))["entries"]["data/codex_tasks/t1/TASK.md"]
    assert {"path", "mtime", "indexed_at", "source_type", "topic_alias_candidates"} <= entry.keys()


def test_corrupt_and_schema_mismatch_rebuild(source_tree, tmp_path):
    state = tmp_path / "state.json"
    state.write_text("{broken", encoding="utf-8")
    assert Indexer(source_tree, state).run().rebuilt_reason == "state_corrupt_or_incompatible"
    state.write_text(json.dumps({"schema_version": 999, "entries": {}, "index_skips": {}}), encoding="utf-8")
    assert Indexer(source_tree, state).run().rebuilt_reason == "state_corrupt_or_incompatible"


def test_json_skip_retry_and_warning_after_more_than_three(source_tree, tmp_path):
    state = tmp_path / "state.json"
    broken = write(source_tree, "data/learning_candidates/LC-broken.json", "{")
    indexer = Indexer(source_tree, state)
    for count in range(1, 5):
        run = indexer.run()
        receipt = run.skipped[0]
        assert receipt["event"] == "index_skip"
        assert receipt["consecutive_failures"] == count
        assert receipt["warning"] is (count > 3)
    time.sleep(0.002)
    broken.write_text('{"fixed":true}', encoding="utf-8")
    os.utime(broken, None)
    recovered = indexer.run()
    assert "data/learning_candidates/LC-broken.json" in recovered.added
    saved = json.loads(state.read_text(encoding="utf-8"))
    assert "data/learning_candidates/LC-broken.json" not in saved["index_skips"]


def test_jsonl_half_write_isolated_from_batch(source_tree, tmp_path):
    state = tmp_path / "state.json"
    metrics = source_tree / "data/metrics/METRICS_LOG.jsonl"
    metrics.write_text('{"ok":1}\n{"half":', encoding="utf-8")
    run = Indexer(source_tree, state).run()
    assert run.skipped[0]["path"] == "data/metrics/METRICS_LOG.jsonl"
    assert "AGENTS.md" in json.loads(state.read_text(encoding="utf-8"))["entries"]
    assert run.model_calls == 0 and run.token_actual == 0


def test_utf8_bom_json_is_valid(source_tree, tmp_path):
    bom_json = source_tree / "data/learning_candidates/LC-bom.json"
    bom_json.write_text('{"topic":"bom"}', encoding="utf-8-sig")
    state = tmp_path / "state.json"
    run = Indexer(source_tree, state).run()
    assert "data/learning_candidates/LC-bom.json" in run.added
    assert not run.skipped
