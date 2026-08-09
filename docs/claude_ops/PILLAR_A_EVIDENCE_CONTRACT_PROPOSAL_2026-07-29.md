# Pillar A 提案：Evidence Contract 第3節 落地缺口修正

status: proposal_only_not_yet_approved
proposer: Claude
date: 2026-07-29
target_document: docs\EVIDENCE_AND_REPORTING_CONTRACT.md（本提案本身不修改該檔案）
requires: Josh 明確核准後才能實作（該文件第11行：「This is a core governance
document. Changes require explicit Josh approval.」）

## 現況（有實測數字，不是推測；母體與口徑已於2026-07-29核准前釐清）

`2026-07-26-agentos-structured-system-audit`（已獨立 Verify PASS）的 Hermes 治理
覆蓋稽核，母體是全部 98 張 `telegram-*` 工單，其中 70 張已有 completed RESULT；
從這 70 張裡實際抽樣檢查的樣本顯示：9 張唯一存在的欄位是 `cleanup_executed`，其餘
樣本多數只有 1/16 或 0/16 個 Evidence Block 欄位；沒有一張樣本填滿完整16欄。這組
98/70 數字是本 session 親自讀取該工單 `OUTPUTS\RESULT.md` 原始內容得到的，可直接
查證。

**口徑澄清**：先前草稿版本另外提到「95張歷史工單」，那是承接自更早session的既有
記憶脈絡，**不是**本次 98/70 這組稽核數字的同一個母體，兩者不應該混用或相加。本
提案只以 98/70 這組、本session可直接查證的數字為準；「95張」的說法在本提案定稿時
予以移除，不寫入任何治理文件，避免用未在本session核實過的數字誤導決策。
Evidence Contract 第3節自 2026-06-24 建立至今超過一個月，依這組已查證數字，實務上
幾乎沒有被真正遵守。

## 為什麼會這樣（診斷，不是指控）

1. **16 欄位不分工單風險等級，一律要求填滿**：一張純讀取、無變更的
   `query-type` 診斷任務，跟一張會寫入 production 的高風險變更，被要求填一模一樣
   的16個欄位（包含 `commit_hash`、`live_external_action_executed` 等對前者根本
   不適用的欄位，雖然規則允許填 `not_applicable`，但實務上這個摩擦本身可能就是
   不填的原因之一）。
2. **沒有自動化檢查、只能靠人工事後稽核發現**：這次能發現「9張只有1個欄位」，
   是靠這個session一次性人工抽樣、獨立稽核才抓到的，平常沒有任何機制會在工單
   完成當下提醒「這張的Evidence Block不完整」。
3. **現有的獨立 Verify 機制某種程度上「補償」了這個缺口**：這個session處理的每張
   工單，即使 Evidence Block 不完整，透過「獨立 Verify」加上「Claude 親自讀原始
   檔案核對」，一樣抓到了真的問題（mojibake假警報、AC1真的FAIL、round-cap真的有
   漏洞）。這代表 Evidence Block 目前比較像「錦上添花的文件紀律」，不是「品質把關
   的唯一防線」——但長期來看，稽核歷史工單、跨 agent 交接時，光靠"每次重新獨立
   查證"成本會越來越高，這正是本提案要解決的問題。

## 提案內容（三個具體改動，供 Josh 逐項核准或否決）

### A1. Evidence Block 分級（降低不必要的摩擦）【2026-07-29 條件式核准，已納入修改】

新增兩種 Block 等級，取代目前「一律16欄」的作法：

- **`full` 等級**（維持現有16欄）：適用於任何會修改 workspace 檔案、寫入
  production、或屬於 `BUILDER_TASK`／`CODEX_BUILD` 類型、或 `change_required: true`
  的工單。
- **`lightweight` 等級（修訂為7欄，不是原案的5欄）**：`task_status`、
  `claimed_by`、`task_kind`、`evidence_sources`、`verification_summary`、
  `verified_by_codex`、`remaining_caveats`。僅適用於明確標記
  `task_kind: read_only` 且沒有 workspace／production／外部狀態變更，或
  Verify bundle 依既有 query-type 邏輯判定為 `change_required: false` 的工單。
  原始5欄版本核准前被指出問題：只有管理性欄位，缺少「查了什麼、依據是什麼」，
  會變成一筆狀態紀錄而不是真正的 Evidence Block，因此加入 `evidence_sources`
  （必須指出實際檢查過的檔案／輸出／命令結果等證據來源）與
  `verification_summary`（必須簡述檢查方式與結論）。

判斷依據寫入工單自己的 `task_kind`／`change_required` 欄位，不由 agent 自由心證
選擇要填哪個等級；兩者判斷衝突時預設用 `full`，不得自動降級。

### A2. 自動化結構性檢查（不做語意驗證，只做「有沒有填」）【2026-07-29 核准，加入漸進式約束】

在 `create_codex_verify_task.ps1` 產生 `VERIFY_BUNDLE.md` 時，新增一個純結構性
掃描：對照 A1 判定的等級（`full`/`lightweight`），計算 RESULT.md 裡實際出現的
必填欄位數，寫入 `evidence_block_field_count: N/16`（或 `N/7`）與
`evidence_block_missing_fields: [...]`。

原案的問題（核准前指出）：只做提示、不產生任何後果，在目前合規率接近零的情況下，
Verify 仍可能繼續 PASS，最後只是多了一個沒人處理的欄位——變成把「沒填欄位」改成
「大家都看得到沒填欄位」，治理止血的效果有限。因此改為分階段生效，而不是一次到位
的機械式擋門：

- **Phase 1**（本次實作範圍）：缺欄位只產生 `WARNING`，不阻擋 Verify，維持
  「Verify 有裁量權、不是機械式擋門」的既有精神。
- **Phase 2**（觀察期，非本次工單範圍）：累積 10-20 張新工單的實際填寫數據後
  再檢視。
- **Phase 3**（未來，非本次工單範圍）：`full` 等級若缺關鍵欄位，Verify 判定 PASS
  時必須在結果中留下明確理由，而不是靜默略過。

本次工單只實作 Phase 1（結構性掃描 + WARNING），Phase 2／3 是後續觀察後才決定是否
啟動，不在這次的實作範圍內。

### A3. 欄位語意小幅澄清（不新增欄位、只是把現有文字寫更精確）

現有規則「Use `not_applicable` if a field does not apply」在實務上似乎沒有被
執行——很可能是因為 agent 不確定「不適用」跟「沒去查」的界線。建議在第3節補一句
明確的判斷準則：「如果你根本沒有嘗試去確認這個欄位對應的狀態，寫 `unknown`；
只有在你已經確認過『這個欄位對這個工單的性質而言邏輯上不可能適用』時，才寫
`not_applicable`」，避免兩者被混用成同一種「沒填」的委婉說法。

## 明確不在本提案範圍內

- 不追溯要求已完成的95張歷史工單補填 Evidence Block（不捏造、不假裝回溯合規）。
- 不讓 `evidence_block_field_count` 過低直接變成自動 FAIL（維持 Verify 的裁量權，
  避免把一個文件紀律問題錯誤地跟「交付本身是否正確」這個更重要的判斷綁死）。
- 不改變第1、2、4-8節既有規則的實質內容。

## 需要 Josh 決定的事

1. 是否核准 A1（分級）、A2（自動化結構性檢查）、A3（文字澄清）——可以逐項核准，
   不需要全部一起接受或拒絕。
2. 若核准，實作工作（修改 `EVIDENCE_AND_REPORTING_CONTRACT.md` 本身 + 修改
   `create_codex_verify_task.ps1` 加入 A2 的掃描邏輯）應該建一張精確範圍的工單，
   交給 Codex 執行、獨立 Verify，不由 Claude 直接動治理正本文件。
