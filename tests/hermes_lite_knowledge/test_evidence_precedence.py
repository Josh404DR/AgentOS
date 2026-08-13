import os
from pathlib import Path

from tools.hermes_lite_knowledge import resolve_verification_status


REAL_TASK = Path("data/codex_tasks/learning-candidate-dedupe-fix-20260721")


def write_outputs(tmp_path, **files):
    task = tmp_path / "task"
    outputs = task / "OUTPUTS"
    outputs.mkdir(parents=True)
    for name, content in files.items():
        (outputs / name).write_text(content, encoding="utf-8")
    return task


def test_real_regression_all_three_questions_have_same_authoritative_answer():
    for _question in (
        "這張工單驗證通過了嗎？",
        "這個修復是已驗證還是還在等驗證？",
        "只看 RESULT.md 的話，這張工單是不是還沒驗證？",
    ):
        answer = resolve_verification_status(REAL_TASK)
        assert answer.final_status == "verified_pass"
        assert answer.external_label == "verified_by_codex"
        assert answer.source_of_truth == "OUTPUTS/VERIFY_RESULT.md"
        assert any(path.endswith("RESULT.md") for path in answer.evidence_paths)
        assert any(path.endswith("VERIFY_RESULT.md") for path in answer.evidence_paths)
        assert "覆蓋" in answer.explanation


def test_verify_fail_and_human_decision_branches(tmp_path):
    for verdict, status in (("FAIL", "verified_fail"), ("NEEDS_HUMAN_DECISION", "escalated_pending_josh")):
        task = write_outputs(tmp_path / verdict, **{
            "VERIFY_RESULT.md": f"verify_verdict: {verdict}\nverified: false\nverified_at: 2026-08-12 Asia/Taipei\n"
        })
        assert resolve_verification_status(task).final_status == status


def test_builder_self_check_pass_is_only_locally_verified(tmp_path):
    task = write_outputs(tmp_path, **{
        "TEST_RESULT.md": "builder_self_check: PASS\nindependent_verify_status: pending\nverified: false\n"
    })
    answer = resolve_verification_status(task)
    assert answer.final_status == "implemented_tests_pass_awaiting_independent_verify"
    assert answer.external_label == "locally_verified"


def test_result_fallback_true_is_downgraded_and_false_is_pending(tmp_path):
    for value, status in (("true", "builder_reported_verified"), ("false", "implemented_pending_verify")):
        task = write_outputs(tmp_path / value, **{"RESULT.md": f"verified: {value}\n"})
        answer = resolve_verification_status(task)
        assert answer.final_status == status
        assert answer.external_label == "claimed_by_agent"


def test_bundle_and_delivery_never_promote_verification(tmp_path):
    task = write_outputs(tmp_path, **{
        "VERIFY_BUNDLE.md": "verify_mode: full_blind_read_only\n",
        "DELIVERY.md": "delivery_status: completed\nverified: true\n",
    })
    answer = resolve_verification_status(task)
    assert answer.final_status == "unknown_no_result_artifact"
    assert answer.source_of_truth == "none"


def test_conflicting_or_malformed_verify_result_fails_closed(tmp_path):
    task = write_outputs(tmp_path, **{
        "VERIFY_RESULT.md": "verify_verdict: PASS\nverified: false\nverified_at: nonsense\n"
    })
    answer = resolve_verification_status(task)
    assert answer.final_status == "review_required"
    assert answer.governance_status == "review_required"


def test_verified_at_before_result_mtime_requires_review(tmp_path):
    task = write_outputs(tmp_path, **{
        "RESULT.md": "verified: false\n",
        "VERIFY_RESULT.md": "verify_verdict: PASS\nverified: true\nverified_at: 2026-01-01T00:00:00+08:00\n",
    })
    result = task / "OUTPUTS" / "RESULT.md"
    os.utime(result, (result.stat().st_atime, 1_800_000_000))
    answer = resolve_verification_status(task)
    assert answer.final_status == "review_required"
    assert answer.governance_status == "review_required"


def test_same_day_date_precision_does_not_invent_midnight(tmp_path):
    task = write_outputs(tmp_path, **{
        "RESULT.md": "verified: false\n",
        "VERIFY_RESULT.md": "verify_verdict: PASS\nverified: true\nverified_at: 2026-08-12 Asia/Taipei\n",
    })
    result = task / "OUTPUTS" / "RESULT.md"
    os.utime(result, (result.stat().st_atime, 1_786_547_600))  # 2026-08-12 in Asia/Taipei
    assert resolve_verification_status(task).final_status == "verified_pass"
