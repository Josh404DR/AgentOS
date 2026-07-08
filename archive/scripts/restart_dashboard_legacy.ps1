Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Start-Process "cmd" -ArgumentList "/c cd /d E:\AgentOS\dashboard\backend && python -m uvicorn main:app --host 0.0.0.0 --port 8000" -WindowStyle Minimized
Start-Sleep -Seconds 2
Start-Process "cmd" -ArgumentList "/c cd /d E:\AgentOS\dashboard\frontend && npm run dev" -WindowStyle Minimized
Write-Host "Dashboard started! Open http://100.66.39.21:3000"
Start-Sleep -Seconds 5