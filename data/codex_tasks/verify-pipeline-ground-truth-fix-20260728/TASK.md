# Task Packet: Verify Pipeline Ground-Truth Fix

dispatch_id: verify-pipeline-ground-truth-fix-20260728
type: CODEX_BUILD
assigned_to: Codex
route_to: Codex
codex_mode: build
task_kind: workspace_change
task_type: Simple
workflow_version: 1.3
impact_scope: scripts\dispatch_task_packet.ps1, scripts\create_codex_verify_task.ps1, tests\test_verify_bundle_generation.ps1, data\codex_tasks\verify-pipeline-ground-truth-fix-20260728\OUTPUTS\
task_status: ready
dispatch_status: ready_to_route
requires_josh_approval: false
approval: Josh direct desktop prompt 2026-07-28
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1

## Objective

Validate Pillar B ground-truth snapshots and add Pillar C fixture coverage.

## Acceptance Criteria

1. Both production scripts pass PowerShell parsing.
2. A fresh offline build dispatch writes a captured GIT_VERIFIED_CHANGES.json.
3. Its automatic Verify bundle contains git_verified_snapshot and evidence_manifest_mismatch.
4. tests\test_verify_bundle_generation.ps1 passes all fixture cases.

## Out of Scope

- Do not modify docs\EVIDENCE_AND_REPORTING_CONTRACT.md.
- Do not modify the seven 2026-07-26 audit-derived tickets.
