# Josh 待辦清單（Claude 無法代替執行）

updated_at: 2026-07-08
由 Claude 維護，Josh 詢問時提醒。

---

## 🔴 P0 — 收入直接相關

- [ ] **W01 人工瀏覽案源**：每天 30 分鐘人工看 104 外包網/PRO360/Tasker/FB 社團，取代死掉的爬蟲
- [ ] **W02 發出第一批提案**：用 `data/proposals/template-apps-script-automation.md` 改寫，目標 10 份/週
- [ ] **W03 推作品集上 GitHub**：三個乾淨副本在 `assets/github-ready/`，直接 `git init` + push

## 🟠 P1 — 需要在電腦前操作

- [ ] **W07 venv git 追蹤清理**：
  ```powershell
  cd E:\AgentOS
  # 先刪 index.lock（若存在）
  Remove-Item .git\index.lock -ErrorAction SilentlyContinue
  git rm -r --cached "data/codex_tasks/2026-06-23-poc-perplexity-api/.venv_perplexity_poc"
  git add .gitignore
  git commit -m "chore: untrack venv, update gitignore"
  ```
- [ ] **W08 index.lock 殘留**：刪除 `E:\AgentOS\.git\index.lock`
- [ ] **W14 Antigravity 排程停用**：停止 Antigravity 4 帳號池的輪詢排程任務
- [ ] **W16 Python launcher 修復**：確認可用的 Python 路徑，更新 `scripts/` 或 `projects/` 的執行方式

## 🔵 待準備進行（需額度或環境就緒）

- [ ] **自主協調閉環煙霧測試**：`dispatch_task_packet.ps1` + bridge 腳本端到端測試，確認 Hermes → TASK.md → Claude → RESULT.md → Hermes 回報全流程可跑。需要 Codex 額度（7/9 12:55 PM 恢復後）或在 Cowork 視窗直接測試。

## 🟡 P2 — 不急，有空再做

- [ ] **W25 根目錄雜物移出**：
  ```powershell
  Move-Item "E:\AgentOS\人生計畫" "E:\人生計畫"
  Remove-Item "E:\AgentOS\新增 文字文件.txt"
  ```
- [ ] **W11 Escalation 清理**：逐筆確認 `data/escalations/ESCALATION_INDEX.jsonl` 中哪些是真實待辦、哪些是 fixture，真實待辦加 RESOLUTION

---

*Claude 會在你問「我要做什麼」或「提醒我」時回報這份清單。*
