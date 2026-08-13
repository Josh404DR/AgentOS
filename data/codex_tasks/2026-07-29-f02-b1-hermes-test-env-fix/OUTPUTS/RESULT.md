# F02 B1 Hermes 測試環境修復結果

dispatch_id: 2026-07-29-f02-b1-hermes-test-env-fix
result_status: partially_completed
change_required: false

## 1. 缺失套件在依賴宣告檔中的狀態

- `agent-client-protocol==0.9.0`：已宣告於 `pyproject.toml` 的 `acp` extra，並鎖定於 `uv.lock`。
- `mcp==1.26.0`：已宣告於 `pyproject.toml` 的 `dev`／`mcp` extra，並鎖定於 `uv.lock`。
- `pydantic-core==2.41.5`：已由 Pydantic 相依鏈鎖定於 `uv.lock`。
- `pytest==9.0.2`、`pytest-asyncio==1.3.0`、`pytest-xdist==3.8.0`、`pytest-split==0.11.0`：已宣告於 `dev` extra。
- `fastapi==0.133.1`、`uvicorn[standard]==0.41.0`：第一輪修復後由剩餘 collection errors 定位，已宣告於 `web` extra。
- Windows 測試程序需要 `which`：不是 Python 套件；使用機器既有的 `C:\Program Files\Git\usr\bin\which.exe` 加入單次測試 PATH，未安裝未宣告套件。

## 2. 實際安裝的套件與版本

安裝目標僅為：

`E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv`

直接安裝並符合宣告版本：

- `agent-client-protocol==0.9.0`
- `mcp==1.26.0`
- `pydantic-core==2.41.5`
- `pytest==9.0.2`
- `pytest-asyncio==1.3.0`
- `pytest-xdist==3.8.0`
- `pytest-split==0.11.0`
- `fastapi==0.133.1`
- `uvicorn==0.41.0`

首次 `uv pip install '.[dev,acp]'` 因 `hermes.exe` 正由其他程序使用，無法替換 executable 而中止。未停止或重啟服務；其後改成只安裝鎖版依賴，成功完成。

## 3. 安裝後完整測試套件 collection 結果

命令排除明確的 `stress`／`integration`／`e2e` 目錄，停用 cache，並使用現有 Git `which.exe`：

```text
24441 tests collected in 45.40s
collection_exit_code=0
```

原先缺少 `acp`／`mcp`／`pydantic_core` 等造成的 17 個 collection errors 已清除。

## 4. 完整測試套件執行結果（跟 B1 218 passed 比對）

- B1 指定基準重跑：

```text
218 passed in 10.26s
exit_code=0
```

- 完整非 stress／integration／e2e suite，serial：

```text
timeout after 300 seconds
exit_code=124
```

- 同一 suite 使用專案已宣告的 `pytest-xdist==3.8.0`、`-n auto`：

```text
timeout after 300 seconds at approximately 55%
multiple test failures observed before timeout
exit_code=124
```

因此可證明原 B1 的 218 項沒有變少，但不能宣稱完整 suite PASS。

## 5. 尚存限制／已知不完美之處

- 完整 24,441 項 suite 未在兩次 bounded 300 秒執行窗內完成。
- 平行 suite 出現多項 failure；因命令在 timeout 時被終止，未取得完整 failure summary，不能判定是否為 Windows／平行隔離／optional integration 環境或程式回歸。
- 未修改任何 `.py` 原始碼或測試檔案；Hermes worktree 原有 unrelated dirty／untracked files 未納入本工單。
- 未啟動、停止或重啟任何 Hermes 服務。

## 6. Evidence Block

task_status: partially_completed
claimed_by: Codex Builder
task_kind: environment_setup
evidence_sources: pyproject.toml; uv.lock; uv install receipts; pytest collection output; pytest targeted output
verification_summary: 24441 tests collected with exit_code=0; B1 baseline 218 passed; full suite timed out and showed failures
verified_by_codex: false
remaining_caveats: full suite did not complete or PASS within bounded timeout; fresh independent B1 Verify required
