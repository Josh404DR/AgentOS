# Fable 5 Prompt 影響分析

updated_at: 2026-07-08
status: 分析完成，等待 Josh 確認

---

## 整體評估：低風險，可執行，有一個硬條件

提示詞的七個動作分兩類：

---

## 新增檔案（C–G）：純加法，零衝突

Dispatch protocol、rubric、templates、maintenance protocol、future-session letter 全是新建獨立檔案，不動現有 AgentOS 任何腳本或治理層。Cowork session 層的改善跟 Hermes/Codex/PowerShell dispatch 是正交的，不會衝突。

---

## CLAUDE.md 改寫：唯一有風險的動作

現在 CLAUDE.md 只有 17 行，核心功能是「強制讀 AGENTS.md 作為 governance gate」。

如果 Fable 5 改寫蓋掉這一行，每個新 session 都會失去治理入口，等於每次都要從頭重建上下文。

---

## 執行前提（需要 Josh 確認後執行）

CLAUDE.md 改寫後：
- `AGENTS.md 強制優先讀取` 必須留在最頂部
- 所有新增內容都 subordinate to AGENTS.md
- 新內容不得聲稱自己高於 AGENTS.md 的治理優先序

守住這三條，整個 prompt 安全可執行。

---

## 附帶說明

Prompt 說「Fable 5」，目前執行環境是 claude-sonnet-4-6，不影響執行品質。

**Josh：確認上述前提沒問題後，請在聊天窗告訴我「執行」即可。**
