# Hermes 快速驗證腳本
$hermes = "E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe"

Write-Host "=== Hermes 驗證 ===" -ForegroundColor Cyan

# 版本
Write-Host "[TEST 1] 版本" -ForegroundColor Green
& $hermes --version
Write-Host ""

# doctor 檢查
Write-Host "[TEST 2] 系統檢查（hermes doctor）" -ForegroundColor Green
& $hermes doctor
Write-Host ""

Write-Host "=== 如果以上沒有錯誤，Hermes 可以正常運作 ===" -ForegroundColor Cyan
Write-Host "下一步：執行 .\scripts\setup_hermes.ps1 設定模型和 Telegram" -ForegroundColor Yellow
