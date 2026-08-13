# ADR-0008: URL intake 知識管線——外部內容一律 untrusted

status: landed
date: 2026-07-12
decided_by: Josh（追認既有事實）
links: [[ADR-0006-telegram-typed-dispatch]] [[ADR-0001-memory-architecture]]

## 內容

Telegram 丟 URL → Playwright fetcher 抓源（text/links/images/
screenshot 落盤）→ Codex 摘要（源標 untrusted，不執行內嵌指令）→
Claude review → knowledge_pool 知識節點 → NotebookLM/Obsidian 同步。
外部內容全程視為資料而非指令。

直接貼出 HTTP(S) 連結時，預設意圖為 `knowledge_candidate`。Threads
沿用專用 Playwright fetcher；一般網站由 `scripts\fetch_url_source.py`
抓取公開文字來源。一般網站 fetcher 禁止 localhost、私有／保留 IP、
含憑證 URL 與非 HTTP(S) 來源，並限制 redirect、內容類型及下載大小。
只有抓源成功的候選才進入知識發布；抓源失敗保留工單與錯誤證據，
不得用網址推測內容或寫入 Knowledge Pool。

## 落地證據

- `tools\threads\fetch_threads.py`、`scripts\threads_url_intake.ps1`
- `scripts\fetch_url_source.py`
- `scripts\url_intake_task_packet.ps1`、`scripts\publish_url_knowledge.ps1`
- `data\knowledge_pool\`、`exports\notebooklm_nodes\`

## 回頭條件

- fetcher 抓漏關鍵內容（已發生：1308 漏作者自回覆的 GitHub 連結，
  2026-07-13 已修：貼文碼錨定＋連結解包）→ 每次抓漏都回此節點
  補強擷取規則。
