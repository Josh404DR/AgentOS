# Build Result — Hermes runtime config decoupling

dispatch_id: 2026-07-29-hermes-runtime-config-decoupling-build
change_required: true
changed_file: config\runtime.local.json
changed_file: scripts\lib\runtime_config.ps1
changed_file: dashboard\backend\main.py
changed_file: scripts\hermes_claude_bridge.ps1
changed_file: scripts\hermes_codex_bridge.ps1
changed_file: scripts\hermes_tripartite_bridge.ps1
changed_file: scripts\start.ps1
changed_file: scripts\start_hermes_lite.ps1
changed_file: scripts\setup_hermes.ps1
changed_file: scripts\test_hermes.ps1
changed_file: scripts\export_obsidian_view_nodes.ps1

## 1. 修改摘要

新增 machine-local `runtime.local.json` 與單一 PowerShell loader，將核准的 Hermes root、executable、Python 與 state DB 路徑集中管理。Dashboard Python 與 Scope 內 PowerShell 腳本不再內嵌 machine-specific 絕對 Hermes 路徑。

## 2. 修改／新增檔案清單

- 新增：`config\runtime.local.json`
- 新增：`scripts\lib\runtime_config.ps1`
- 修改：`dashboard\backend\main.py`
- 修改：`scripts\hermes_claude_bridge.ps1`
- 修改：`scripts\hermes_codex_bridge.ps1`
- 修改：`scripts\hermes_tripartite_bridge.ps1`
- 修改：`scripts\start.ps1`
- 修改：`scripts\start_hermes_lite.ps1`
- 修改：`scripts\setup_hermes.ps1`
- 修改：`scripts\test_hermes.ps1`
- 修改：`scripts\export_obsidian_view_nodes.ps1`

## 3. 關鍵邏輯與 fail-closed 流程

PowerShell `Get-AgentOSRuntimeConfig` 與 Python `_load_runtime_config` 均依序驗證：

1. config 必須存在且是檔案；
2. JSON 必須能嚴格解析；
3. `schema_version`、`hermes.root/executable/python/state_db` 必須存在且非空；
4. 四個路徑必須是絕對路徑；
5. Hermes root 必須是現存目錄；
6. Hermes executable 與 Python 必須是現存檔案。

任一步失敗即拋出精確錯誤，不會回退為原硬編碼絕對路徑。Bridge 與 Lite 腳本保留原有的顯式 `HermesRoot` 參數覆寫相容性，但仍必須先成功載入有效 config。

## 4. 測試案例與實測結果

完整結果見：

- `E:\AgentOS\data\codex_tasks\2026-07-29-hermes-runtime-config-decoupling-build\OUTPUTS\TEST_RESULT.md`

核心結果：三種 fail-closed fault injection 全部得到預期拒絕；PowerShell syntax、Python compile、BOM policy、Dashboard UX contract、Dashboard 17 項 security tests、Dashboard import runtime smoke 與 setup smoke PASS。Hermes doctor 有 sandbox 網路／ACL及編碼 thread 警告但腳本 exit 0。

## 5. 尚存限制

- `config\runtime.local.json` 是 machine-local 且目前 untracked；`.gitignore` 不在本工單 Scope，未擅自修改。若日後要提交或建立範本，需另行核准政策。
- Scope 內多個檔案在本工單開始前已有未提交變更；本次保留並合併，未刪除或回滾。
- 全新 read-only Codex Verify session 已獨立出具 PASS；原始回執位於 Verify 子票。

## 6. SCOPED_DIFF.patch

`E:\AgentOS\data\codex_tasks\2026-07-29-hermes-runtime-config-decoupling-build\OUTPUTS\SCOPED_DIFF.patch`

## 7. Commit

commit_hash: not_created

## 8. Evidence Block

task_status: verified_by_codex
claimed_by: Codex Builder
artifact_status: artifact_created
locally_verified: true
verified_by_codex: true
reviewed_by_claude: unknown
approved_by_josh: true
cleanup_executed: false
live_external_action_executed: false
files_modified: dashboard\backend\main.py; scripts\hermes_claude_bridge.ps1; scripts\hermes_codex_bridge.ps1; scripts\hermes_tripartite_bridge.ps1; scripts\start.ps1; scripts\start_hermes_lite.ps1; scripts\setup_hermes.ps1; scripts\test_hermes.ps1; scripts\export_obsidian_view_nodes.ps1
files_created: config\runtime.local.json; scripts\lib\runtime_config.ps1; OUTPUTS\RESULT.md; OUTPUTS\TEST_RESULT.md; OUTPUTS\SCOPED_DIFF.patch
commit_hash: not_created
evidence_paths: E:\AgentOS\data\codex_tasks\2026-07-29-hermes-runtime-config-decoupling-build\OUTPUTS\RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-hermes-runtime-config-decoupling-build\OUTPUTS\TEST_RESULT.md; E:\AgentOS\data\codex_tasks\2026-07-29-hermes-runtime-config-decoupling-build\OUTPUTS\SCOPED_DIFF.patch
verification_commands: assert_governance_ready.ps1; PowerShell Parser.ParseFile; hermes.python -B -m py_compile; C:\tmp\agentos-runtime-config-tests\test-runtime-config.ps1; tests\test_powershell_utf8_bom.ps1; tests\test_dashboard_ux_contract.ps1; scripts\setup_hermes.ps1; scripts\test_hermes.ps1
remaining_caveats: pre-existing scoped dirty changes retained; Hermes doctor emitted sandbox network/ACL and cp950 reader-thread warnings
production_ready: false

## Acceptance checklist

- AC1 config schema／machine-local values：pass
- AC2 shared PowerShell loader／8 scripts：pass
- AC3 observable behavior unchanged：pass（syntax、compile、setup/test smoke、Dashboard import 與 17 項 security suite 支持）
- AC4 三種 fail-closed fault injection：pass
- AC5 fresh independent read-only Verify：pass

final_status: verified_by_codex
