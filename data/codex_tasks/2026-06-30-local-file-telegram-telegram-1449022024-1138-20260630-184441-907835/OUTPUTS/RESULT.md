**狀態**  
已完成。新增 `E:\AgentOS\scripts\dispatch_task_packet.ps1`，會讀取 `E:\AgentOS\data\codex_tasks\<DispatchId>\TASK.md`，解析 `assigned_to`，並依路由呼叫對應 bridge。未 commit、未 push、未呼叫外部服務。

**Files Changed**  
- `scripts\dispatch_task_packet.ps1`
- `scratch\dispatch_task_packet_selftest\...`：本機驗證用任務封包與 dummy bridge，保留作為測試證據。

**接口說明**  
- `Claude Worker` → `scripts\hermes_claude_bridge.ps1 -BridgeId <DispatchId> -AgentOSRoot E:\AgentOS -ClaudePrompt "Process AgentOS task packet: <TASK.md path>"`
- `Claude Inspector` → `scripts\hermes_tripartite_bridge.ps1 -BridgeId <DispatchId> -AgentOSRoot E:\AgentOS -TaskSeed "Inspect AgentOS task packet: <TASK.md path>"`
- `Ollama` → 若存在，呼叫 `scripts\free_model_window.ps1 -AgentOSRoot E:\AgentOS -Message "Process AgentOS task packet: <TASK.md path>"`

**測試指令範例**  
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\dispatch_task_packet.ps1 -DispatchId <DispatchId> -DryRun
```

實際執行：
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\AgentOS\scripts\dispatch_task_packet.ps1 -DispatchId <DispatchId>
```

**Verification**  
已驗證：
- 缺少 `TASK.md` 時會輸出 `TASK.md not found: ...` 並退出。
- `Claude Worker`、`Claude Inspector`、`Ollama` 三種 `assigned_to` dry run 路由成功。
- 使用 scratch dummy bridge 做非 dry run，確認參數會正確逐項傳入，不是單一陣列物件。

**Issues**  
目前這個任務封包本身沒有 `assigned_to` 欄位，所以直接對它 dry run 會回報 `assigned_to field not found in TASK.md`，這符合腳本防呆行為。

**Recommended Next Step**  
在實際要派送的 `TASK.md` 補上例如 `assigned_to: Claude Worker`，再先跑一次 `-DryRun` 確認路由。