# Hermes 首次設定腳本
# 在 Hermes 安裝好之後執行一次

$HermesVenv = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe"

Write-Host "=== Hermes 首次設定 ===" -ForegroundColor Cyan

# 步驟 1：確認版本
Write-Host "[1/4] 確認 Hermes 版本" -ForegroundColor Green
& $HermesVenv --version

# 步驟 2：設定模型（Claude 訂閱）
Write-Host ""
Write-Host "[2/4] 設定模型" -ForegroundColor Green
Write-Host "請在 Hermes 啟動後執行：hermes model" -ForegroundColor Yellow
Write-Host "選擇 Anthropic → 登入 Claude 帳號（使用訂閱，不需 API key）"

# 步驟 3：設定 Telegram
Write-Host ""
Write-Host "[3/4] 設定 Telegram" -ForegroundColor Green
Write-Host "請執行：hermes gateway setup" -ForegroundColor Yellow
Write-Host "依照指示建立 Telegram bot 並取得 token"

# 步驟 4：設定 LINE（台灣主力）
Write-Host ""
Write-Host "[4/4] 設定 LINE（可選）" -ForegroundColor Green
Write-Host "請執行：hermes gateway setup --platform line" -ForegroundColor Yellow
Write-Host "需要 LINE Messaging API channel token"

Write-Host ""
Write-Host "=== 設定完成後，執行 .\scripts\start.ps1 ===" -ForegroundColor Cyan
