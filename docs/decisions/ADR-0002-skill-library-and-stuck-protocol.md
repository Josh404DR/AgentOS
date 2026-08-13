# ADR-0002: skill 庫走 lazy-load INDEX；卡住走三層階梯，不寫死背景技能

status: accepted
date: 2026-07-12
decided_by: Josh + Claude 討論
links: [[ADR-0001-memory-architecture]]
related_plan: docs/plans/2026-07-12-result-chain-optimization.md（Phase 4 學習迴路）

## 處境（Context）

skill（教訓沉澱的程序性知識）如果全部寫死在 worker 背景 prompt，
context 成本隨 skill 數線性膨脹。Josh 提議：agent 卡住時再查，
不要預載。

## 決定（Decision）

1. **Lazy-load**：背景只載 `skills/INDEX.md`（一行一條：觸發條件 → 檔案），
   命中才讀全文。Claude Code skill 機制的同型作法。現階段不用 RAG。
2. **Stuck-protocol 三層階梯**：卡住 → ①查 skill 庫（免費）→
   ②帶上下文問高階模型（燒少量 token）→ ③才 escalate 給 Josh。
   走到②才解掉的問題＝下一份 skill 的天然素材。
3. **卡住偵測用客觀條件，不靠 worker 自覺**（1316 教訓：worker 缺
   WebSearch 權限卻不自知，自信交出訓練資料答案）。觸發條件：
   缺權限／缺工具／verify 連續 FAIL 兩次／與 governance 矛盾／
   test_command 無法執行。
4. **沉澱門檻**：同 pattern 出現 ≥2 次才蒸餾成 skill；一次性問題修完即可。
   防止 skill 庫變垃圾場。

## 回頭條件

- skills/INDEX.md 超過數百條 → 回 ADR-0001 的 RAG 分叉。
- stuck-protocol ②層命中率過低（高階模型也解不了）→ 檢討觸發條件設計。
