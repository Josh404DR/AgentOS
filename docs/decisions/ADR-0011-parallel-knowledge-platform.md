# ADR-0011: 知識平台與量化路線並行——修正 ADR-0010 凍結範圍

status: accepted
date: 2026-07-20
decided_by: Josh（於 Claude Cowork 對話中口頭裁決，本檔為落盤紀錄）
links: [[ADR-0010-converge-before-expand]] [[ADR-0008-url-intake-knowledge-pipeline]] [[ADR-0007-dashboard-evidence-console]]

## 背景

「Telegram × Dashboard 知識工作平台計畫」（2026-07-20 討論草案）與
ADR-0010／current_state.md §7（07-13 版）的「其餘凍結」存在優先序
衝突：該計畫屬擴張型建設，而 07-13 核准路線要求 metrics baseline
完成前凍結新功能。

## 決策

Josh 裁決：**知識平台工單與系統優化（量化路線）可同時進行，不衝突。**

1. ADR-0010 的「凍結擴張」不再涵蓋知識平台 Phase 0（安全地基）與
   Phase 1（唯讀知識工作台）；兩者可與量化路線並行推進。
2. Phase 2（promotion／publish）與 Phase 3 仍維持草案，未授權實作，
   待 Phase 0/1 安全驗收與獨立驗證通過後由 Josh 單獨啟用。
3. 量化路線（儀表板八指標 → 修假失敗 → 查詢分流 → 自動學教訓 →
   50~100 張工單觀察窗）優先序不變，仍為主線。
4. 首張工單拆小：先做「Phase 0 安全地基」，fresh Codex Verify PASS
   後才開 Phase 1 工單。owner authentication 機制定為**本機短效
   token 檔**（僅 Josh 帳號可讀）。

## 回頭條件

- 若量化路線因與知識平台搶資源（worker 額度、Josh 決策頻寬）而
  停滯超過一週，知識平台工單讓路、回到 HOLD，量化路線恢復獨占。
- 若 Phase 0 驗收兩輪修正後仍無法通過，知識平台整體回到草案狀態
  重審，不得帶病進 Phase 1。

## 影響

- current_state.md §7 同步更新（2026-07-20 版）。
- ADR-0010 其餘紀律（先量測、確定性優先、不捏造數字）完全不變，
  並適用於知識平台工單本身。
