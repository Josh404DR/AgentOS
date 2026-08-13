# Upwork 提案模板 — Google Apps Script / Sheets 自動化
# 用途：填入實際案源資訊後直接送出
# 更新：2026-06-30

---

## 使用說明

1. 找到 `[替換]` 標記的欄位，填入真實資料
2. 刪除「## 使用說明」和所有 `[替換]` 前的說明文字
3. Josh 審核後送出，不可由 agent 自動送出

---

## 案源資訊（內部用，不貼給客戶）

```
案源標題：[替換]
Upwork URL：[替換]
預算：[替換]
客戶需求摘要：[替換]
送出時間：[替換]
```

---

## 正式提案內容（貼給客戶）

---

Hi [替換：客戶名字或留空],

I've built Google Sheets + Apps Script workflows for [替換：類似情境，例如 "invoice tracking", "inventory sync", "report automation"] and this project aligns well with what I do.

**What I understand you need:**
[替換：用 1–2 句話說明你對需求的理解，例如：]
- Automatically pull data from [來源] into Google Sheets on a schedule
- Clean and format the data, then send a summary report via email

Before diving in, a few quick questions to make sure I scope this right:

1. [替換：最關鍵的澄清問題，例如 "Is the data source a REST API, another Sheet, or a CSV export?"]
2. [替換：第二個問題，例如 "Do you need this to run automatically on a schedule, or triggered manually?"]
3. [替換：第三個問題，例如 "Are there any existing Scripts in the Sheet I should know about?"]

**My approach:**
1. Review your current Sheet structure and confirm the data source
2. Build the Apps Script with clear logging so you can see what ran and what was skipped
3. Add error handling — if anything fails, it won't silently corrupt your data
4. Test with real data and walk you through how it works

**Why this approach works:**
I keep the logic inside Apps Script (no external servers, no ongoing fees) and structure the code so you or your team can read and maintain it after delivery.

**Timeline & rate:**
[替換，例如：]
- Estimated: 2–4 days after requirements are confirmed
- Fixed price: $[替換] (subject to API docs review if an external API is involved)

Happy to jump on a quick call to go over the details before committing to a scope.

[替換：你的名字]

---

## 提案補充說明（針對不同情境選填）

### 情境 A：有外部 API 整合

加在「My approach」後面：

> One thing I want to flag: if the API requires OAuth or service accounts, setup adds a day. I'll confirm the auth method first and adjust the estimate if needed — no surprises after we start.

### 情境 B：客戶有現有 Script 需要修改

加在開頭：

> I reviewed the description carefully — fixing and extending existing Scripts is something I do regularly. I'll read the current code first before touching anything, and I'll document what I changed and why.

### 情境 C：需要定時觸發（Cron-style）

加在「My approach」：

> For the scheduled trigger, I'll use Apps Script's built-in time-based triggers so there's nothing external to maintain. I'll also add a run log tab so you can always see the last execution time and status.

---

## 價格參考區間

| 規模 | 說明 | 建議區間 |
|---|---|---|
| 簡單 | 單一 Sheet 格式化 / 資料整理 | $150–$300 |
| 中等 | 跨 Sheet 彙整 + email 通知 | $300–$600 |
| 中大 | 外部 API 同步 + error handling | $600–$1,000 |
| 大型 | 多 API + 複雜邏輯 + 交接文件 | $1,000–$2,000 |

---

## 送出前檢查清單

- [ ] 理解客戶需求，不是亂猜
- [ ] 澄清問題針對這個案子（不是通用問題）
- [ ] 沒有承諾確定完工日期（先說「after requirements confirmed」）
- [ ] 沒有承諾 OAuth 實作（除非確認 API auth）
- [ ] Josh 已看過並同意送出
- [ ] 刪除所有 `[替換]` 標記
