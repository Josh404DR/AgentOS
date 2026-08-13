Start-Process "tailscale" -ArgumentList "login" -NoNewWindow
Start-Sleep -Seconds 5
tailscale ip --4 | Out-File "E:\AgentOS\data\monitoring\network\tailscale_ip.txt" -Encoding UTF8
