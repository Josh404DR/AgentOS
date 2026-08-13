# Josh 開 Hermes 備忘

用途：忘記怎麼開 Hermes gateway 時，看這份。

## 推薦開法

這個會從 AgentOS 啟動 Hermes gateway，並跳過目前還沒登入成功的 proxy。

```powershell
cd E:\AgentOS
.\scripts\start.ps1 -SkipProxy
```

備註：

- 推薦平常用這個。
- `-SkipProxy` 很重要，因為 Hermes proxy 目前的 `nous` / `xai` upstream 還沒登入，直接開 proxy 可能會失敗。
- 開完後可以用下面指令確認：

```powershell
& "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe" gateway status
```

## 直接開 Hermes gateway

這個會直接啟動 Hermes gateway。

```powershell
& "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe" gateway run --accept-hooks
```

備註：

- 這個會佔住目前的終端機視窗。
- 終端機關掉，gateway 通常也會停。
- 看到類似下面訊息就是有啟動：

```text
Hermes Gateway Starting...
Messaging platforms + cron scheduler
Press Ctrl+C to stop
```

## 現在要記得

- 先開 gateway，不要急著開 proxy。
- Telegram / cron 要靠 gateway 跑。
- 如果要長時間跑，之後再處理 Windows service 或 watchdog。
