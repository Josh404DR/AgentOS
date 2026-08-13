# Ollama 本地模型評測結果

status: frozen — 評測已完成，不再擴建
completed_at: 2026-06-26
frozen_at: 2026-07-08（依據稽核報告 W23）

---

## 評測摘要

| 目錄 | 內容 |
|---|---|
| `2026-06-26-practical/` | 實用能力評測（結構化任務、程式碼、分析） |
| `2026-06-26-practical-nothink/` | 同上，關閉 think 模式 |
| `2026-06-26-speed-nothink/` | 速度評測，關閉 think 模式 |

## 結論（已採納至 hermes_system_prompt_v2）

| 模型 | 建議用途 |
|---|---|
| `qwen2.5-coder:7b` | 最佳本地結構化 worker |
| `qwen3:8b` | 搭配 `think=false` 做 evidence-audit / URL-intake 草稿 |
| `llama3.2:3b` | 最快的低風險格式化任務 |
| `qwen3.5:9b` | 不建議用於常規任務佇列（速度/穩定性不足） |

## 凍結說明

本目錄的評測結論已整合進系統提示詞，不需要繼續擴建。
若未來有新模型需要評測，在此目錄新增子目錄即可，但須等第一筆收入後再議。
