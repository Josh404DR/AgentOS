# Escalation Decision Hardening Result

dispatch_id: escalation-decision-hardening-20260720
task_status: completed
builder: Codex Builder
governance_version: 1.3.0
governance_hash: 0EAECF6D153925AC17B940992CC12CE82A6DE5E7F1D7B766BAB9C479C3088EB1
verified: true
verify_verdict: PASS
verify_attempt: 1
verify_thread_id: 019f7fcf-4083-79c0-b1a8-cca2748d8b38
external_task_data_sent: false

## 實際結果

- `decide_escalation.ps1` 不再信任 `ActorId`／`AuthMethod` 字串；缺回執、空值、`current_chat_explicit_instruction`、`prior_instruction`、未知來源或無效簽章均在寫入 DECISION 前 fail-closed，並追加拒絕 audit，狀態保持 `awaiting_josh`。
- 合法 Dashboard 路徑沿用 Phase 0 owner session、Origin 與 CSRF 驗證，簽發短效 HMAC receipt；receipt 綁定 task、decision、actor、authentication method、request ID 與有效時間。
- decision 與 queue 使用同一確定性 receipt validator；queue 對無回執或無效 DECISION 回報 `escalation_decision_receipt_invalid:<exact_reason>`，不前進。
- receipt 為一次性；已使用 receipt 不得由 decision script 重複消費。已完成的合法 DECISION 會驗證「decided_at 位於 receipt 有效窗內」，不因 receipt 日後自然過期而失效。
- escalation 建立後少於預設 10 秒的決策會寫入 `suspicious_fast_decision=true`，並追加 audit；不因此自動拒絕 Josh 的合法快速決策。
- Dashboard 不再把 legacy/model-authored `owner_decision` resolution 當成 Josh 回執；既有 Phase 1 紀錄仍保留原檔，但 UI/API 狀態回到 `awaiting_josh`。
- 沒有修改 `AGENTS.md`、Dashboard mutation flag 值、既有 escalation JSON、Phase 1 交付或 dispatcher 核心。

## 驗證摘要

- hardening 專項：PASS。
- Dashboard／Knowledge／URL／relations：41 tests PASS。
- Dashboard production build：PASS。
- queue failure containment：PASS；queue reason propagation：PASS。
- dispatch resilience 獨立重跑：6/6 PASS。
- CI smoke `ci-smoke-20260720-214107`：本單 gate PASS，唯一 FAIL 為範圍外 `model_cli_live_smoke: cmd.exe Access is denied`。
- CI smoke `ci-smoke-20260720-214610 -SkipModelCliSmoke`：本單 gate PASS；唯一 FAIL 為 timeout fixture child cleanup race。該 PID 隨即不存在，獨立重跑 6/6 PASS。兩份原始 CI 證據均保留，未改判或刪除。

## 歷史證據 hash

- `20260720-175701-586.json`: `456944722C23E1E3DAB6F39079EE62FA4DC10C1C4F2DD9C2D0009E88C586EBA0`
- `DECISION-20260720-175702-117.json`: `4B0B2A8BCA60EDF708DC15DD1D1DF9C5D4656F00CDF12A0AB2373D15552E636D`
- `RESOLUTION.json`: `E0CCC2176AE61C78024FA39B56F7842B7305CAA5866A66C25A5C7BDFC4DE66D0`

## 未解風險

- Telegram 一次性確認 receipt 的 validator schema 已 fail-closed 支援，但本機沒有可用 Telegram bot command-receipt issuer；目前合法可用通道是 Dashboard owner session。兩者皆不可用時維持 `awaiting_josh`，符合工單設計。
- 工作區治理狀態仍是 `operational_review_required`；不阻擋本工單驗證，但不可宣稱整個工作區 production-ready。
- full smoke 的兩個範圍外／fixture caveat 仍保留於原始 CI artifact；fresh Verify 已確認它們不是本單 regression。

## 下一步

- 本工單已由第 1 次全新 read-only Codex Verify 對七項 acceptance criteria 出具嚴格 PASS。
