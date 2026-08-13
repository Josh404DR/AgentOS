# PowerShell 呼叫 Dashboard API：UTF-8

Windows PowerShell 5.1 呼叫含中文的 Dashboard API 時，必須同時宣告 JSON charset，並把 body 明確轉為 UTF-8 bytes。不要直接把 `ConvertTo-Json` 的字串交給舊版 `Invoke-RestMethod`。

```powershell
$payload = @{
    decision = "modify"
    note = "請補上驗證證據"
} | ConvertTo-Json
$body = [Text.Encoding]::UTF8.GetBytes($payload)

Invoke-RestMethod `
    -Uri "http://127.0.0.1:8000/api/approvals/<task-id>/decision" `
    -Method Post `
    -WebSession $ownerSession `
    -Headers @{
        Origin = "http://localhost:3000"
        "X-CSRF-Token" = $csrfToken
        "X-Request-ID" = [guid]::NewGuid().ToString()
    } `
    -ContentType "application/json; charset=utf-8" `
    -Body $body
```

Backend 會拒絕全問號或含 Unicode replacement character (`U+FFFD`) 的 decision note，避免錯誤編碼形成不可修復的歷史紀錄。
