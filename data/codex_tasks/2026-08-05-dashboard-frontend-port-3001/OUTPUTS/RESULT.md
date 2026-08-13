# AgentOS Dashboard 與 SCC 同時運行修正結果

dispatch_id: 2026-08-05-dashboard-frontend-port-3001  
governance_version: 1.3.0  
governance_status: operational_review_required  

## 變更

- `dashboard/start.ps1` 新增 `FrontendPort` 參數，預設 3002；start、stop、orphan guard、health、receipt、browser 與輸出 URL 全部使用同一值。
- production/dev command 分別傳入 `npm run start -- --port 3002`／`npm run dev -- --port 3002`。
- `dashboard/backend/dashboard_security.py` 保留 SCC 使用的 3000/3001 origins，並加入 AgentOS 3002 origins。
- `config/runtime_registry.json` 將 Dashboard frontend health、port 與 control args 同步為 3002。
- 原擬使用 3001；live listener evidence 顯示 SCC governance portal 同時使用 IPv6 loopback 3000 與 3001，因此改選 3002。未停止、修改或接管 SCC process。

## 測試與 live evidence

- PowerShell parser：PASS。
- runtime registry JSON parse：PASS。
- `tests/test_dashboard_orphan_guard.ps1`：PASS。
- `python -m unittest tests.test_dashboard_security -v`：17/17 PASS。
- HTTP：SCC 3000=200、SCC 3001=200、AgentOS 3002=200、AgentOS backend 8000 `/api/health`=200。
- listener：3000 PID 26148 與 3001 PID 1312 的 command line 均驗證為 SCC governance-portal vinext；3002 PID 35744 驗證為 `E:\AgentOS\dashboard\frontend` Next.js；8000 PID 24944 驗證為 uvicorn `main:app`。
- lifecycle receipt：`runtime_id=dashboard-frontend`、`status=running`、`port=3002`、parent PID 36016、`command_match=npm run start -- --port 3002`。listener 是該 cmd parent 的 node child。

## 已知限制

- `dashboard/start.ps1` 與 `dashboard/backend/dashboard_security.py` 在目前 worktree 本來就是 untracked operational files；本工單未擅自 stage、commit 或覆蓋 main。
- runtime registry 是 tracked modified；未 commit／push。
- scheduled task 下次無參數啟動會取得新預設 3002；runtime registry control args 也已明示 3002，但本次未觸發 Task Scheduler 做額外重啟。
- governance 為 `operational_review_required`，不宣稱整體 production-ready。
- 第一個 fresh read-only Verify 因 builder 自建 AC 誤寫為 SCC IPv4 `127.0.0.1:3000` 而 FAIL；實際 SCC 僅監聽 `[::1]`，`localhost:3000/3001` 均為 200。原始 Josh 需求未要求修改 SCC binding，故已修正 AC 為 localhost 實況並保留 `OUTPUTS/VERIFY_RESULT_ATTEMPT1.md`；第二個 fresh read-only Verify 已判定 PASS。

## Acceptance checklist

- pass：SCC 3000/3001 持續 200，owner process 未被終止。
- pass：AgentOS frontend 3002 回 200。
- pass：AgentOS backend 8000 回 200。
- pass：receipt 與 runtime registry 均為 3002。
- pass：security 17/17 與 orphan guard PASS。
- pass：修正自建 AC 後的第二個 fresh independent Verify PASS。

## Evidence Block

task_status: verified_by_codex  
claimed_by: Codex Builder  
artifact_status: artifact_created  
locally_verified: true  
verified_by_codex: true  
reviewed_by_claude: unknown  
approved_by_josh: true  
cleanup_executed: not_applicable  
live_external_action_executed: true  
files_modified: `E:\AgentOS\dashboard\start.ps1`; `E:\AgentOS\dashboard\backend\dashboard_security.py`; `E:\AgentOS\config\runtime_registry.json`  
files_created: `E:\AgentOS\data\codex_tasks\2026-08-05-dashboard-frontend-port-3001\TASK.md`; `E:\AgentOS\data\codex_tasks\2026-08-05-dashboard-frontend-port-3001\OUTPUTS\RESULT.md`; runtime receipt/log state  
commit_hash: not_created  
evidence_paths: TASK.md; OUTPUTS/RESULT.md; OUTPUTS/VERIFY_RESULT_ATTEMPT1.md; OUTPUTS/VERIFY_RESULT.md; `E:\AgentOS\data\runtime_receipts\dashboard-frontend.json`; `E:\AgentOS\logs\dashboard-frontend.stdout.log`; runtime listener/HTTP command output  
verification_commands: governance gate; PowerShell parser; ConvertFrom-Json; test_dashboard_orphan_guard.ps1; unittest tests.test_dashboard_security; privileged HTTP/listener/CIM/receipt audit  
remaining_caveats: operational drift; two source files preexisting untracked; no Task Scheduler invocation test; SCC is IPv6-loopback-only; first Verify failed on builder-authored IPv4 AC and is preserved; corrected task passed second fresh Verify  
production_ready: false  

changed_file: dashboard/start.ps1  
changed_file: dashboard/backend/dashboard_security.py  
changed_file: config/runtime_registry.json  
changed_file: data/codex_tasks/2026-08-05-dashboard-frontend-port-3001/TASK.md  
changed_file: data/codex_tasks/2026-08-05-dashboard-frontend-port-3001/OUTPUTS/RESULT.md  
change_required: true  
