# AgentOS Recommendations

Updated: 2026-07-06 Asia/Taipei
Last synced from: `progress_log.md`, `current_state.md` (through 2026-07-06)
Maintained by: **Cursor only**
Owner: Josh Hsu
Purpose: Prioritized improvement suggestions for AgentOS. This is advisory guidance, not a canonical spec. For architecture and status, see `docs\ARCHITECTURE.md` and `current_state.md`.

### Document Ownership

This file is a **Cursor-owned external analysis artifact**. Codex, Hermes, Claude, and other agents may read and cite it but must not edit it. See `E:\AgentOS\archive\Cursor_use\PROJECT_ANALYSIS.md` for the full ownership rule.

---

## Recent Progress (through 2026-07-06)

| Item | Status | Evidence |
|---|---|---|
| Telegram typed dispatch hook | **Done** | Live verified; `[TYPE: ...]` skips full Hermes agent |
| Hermes Lite plain chat (Groq) | **Done** | Ordinary messages use no-tools free window; avoids Gemini + Groq 413 |
| Daily-Token-Cost-Summary cron | **Done** | No-agent mode; `models_invoked=false` |
| Free cloud window guard + Hermes providers | **Done** | `agentos-groq`, `agentos-openrouter-free`; `/model status` hotfix |
| URL intake → Codex worker loop | **Done** | First closed dispatch→worker→RESULT cycle |
| Ollama practical + speed eval | **Done** | `qwen2.5-coder:7b` recommended structured worker |
| NotebookLM conveyor (DryRun) | **Done** | 03:30 schedule; 43 sources / 44 Markdown in dry-run |
| Phase 1-03 Root Cleanup | **Done** | Cleared 8 root-level miscellaneous files; drift_count=0 aligned status |
| Antigravity Handoff automation | **Done** | `send_task_to_antigravity.ps1` and `AGENTOS_ROLE.md` created & verified |
| General CODEX_VERIFY / CLAUDE_REVIEW auto-worker | **Not done** | Still stops at `ready_to_route` |
| Lead patrol (Upwork) | **Blocked** | Cloudflare Turnstile |
| External URL fetch in URL intake | **Blocked** | Requires Josh approval |

---

## Summary

AgentOS **infrastructure advanced significantly in late June and early July**. Cost controls, the URL intake worker loop, root directory cleanup, and the automated Antigravity handoff script are the biggest wins. Business flow (real leads → proposals → delivery) remains the primary gap.

Recommended order: **semi-automatic leads → escalation index sync → credentials security migration**.

---

## P0: Unblock the Main Chain

### 1. Lead Patrol Is Blocked — Use Semi-Automatic Intake

Upwork Cloudflare Turnstile still blocks automated patrol. Do not invest in scrapers (`scrape_upwork.py` = high ToS risk; now deleted).

**Recommendations:**

- **Short term**: Josh pastes Upwork job URLs in Telegram → Hermes Lite triggers existing **URL_INTAKE** pipeline → Codex writes structured lead analysis to `OUTPUTS\RESULT.md` → Hermes/Human promotes to `data\leads\` and `screening_log.md`
- **Medium term**: Evaluate Upwork official API or manual dashboard workflow
- **Governance**: Completed quarantine and deletion of `scrape_upwork.py`

This reuses the **already-working URL intake loop** instead of building a new lead scraper.

### 2. Wire General Typed-Dispatch Workers (Beyond URL_INTAKE)

URL intake proved the pattern. Replicate for other types:

```text
[TYPE: CODEX_VERIFY]
  -> typed_dispatch (done)
  -> dispatch_worker.ps1 or bridge (NOT done)
  -> OUTPUTS/RESULT.md
  -> Telegram summary
```

Implement **`CODEX_VERIFY` first**, then `CLAUDE_REVIEW`. Extract shared logic from `url_intake_worker.ps1`.

### 3. Complete the First Real Business Cycle

No full **lead → screening → proposal → codex → Josh** production cycle yet.

**Suggested path:**

- Josh sends 1–2 real Upwork URLs via Telegram
- Promote Codex URL intake result into `data\leads\` + `data\proposals\`
- Run Claude review on proposal draft
- Josh approves before any client-facing action

---

## P1: Cost and Stability

### 4. Gemini Usage — Mostly Addressed; Tighten Remaining Paths

| Scenario | Status |
|---|---|
| `[TYPE: ...]` messages | **Done** — skip Gemini |
| Plain Telegram chat | **Done** — Hermes Lite / Groq |
| Cron daily token summary | **Done** — no-agent |
| Lead/proposal analysis | **Not done** — needs `[TYPE: GEMINI_PREMIUM]` gate |
| Full Hermes agent on Groq | **Blocked by design** — 413 / 6k TPM; do not retry |

**Still recommended:** weekly cap + auto degraded mode in `budget_state.json`.

### 5. Hermes Lite Polish

- Confirm gateway restart loaded UTF-8 hook decoder (mojibake fix was applied 2026-06-25)
- Monitor Groq daily cap (30 requests) under active Telegram use
- Document when Josh should use `/model groq` for full (non-lite) sessions vs Hermes Lite default

### 6. Ollama Routing — Apply Evaluation Results

Evaluation complete. Route accordingly:

| Task | Model |
|---|---|
| Structured local worker | `qwen2.5-coder:7b` with `think=false` for Qwen |
| Fast formatting | `llama3.2:3b` |
| Routine queues | **Avoid** `qwen3.5:9b` (too slow) |

Do not use Ollama as final authority for approval, safety, or external URL decisions.

### 7. Gateway / Proxy Decision

Live gateway uses `hermes gateway run --accept-hooks` from AppData. Proxy 8080 still lacks Claude upstream.

**Pick one:** document Claude = CLI bridge only, or fix proxy upstream.

---

## P2: Governance and Security

### 8. Resolve Pending Evidence Cleanup

Manifest ready; `cleanup_executed=false`. First batch: duplicates/temp only. Classify `PROJECT_ANALYSIS.md` and `RECOMMENDATIONS.md` as `keep_external_cursor_owned`.

### 9. Fix `env_manager.py` Plaintext Secrets

Medium risk. Move secrets to Credential Manager or gitignored `.env`.

### 10. External URL Fetch Policy for URL Intake

URL worker completes with `external_access_required=true` and `josh_approval_required=true`.

**Define explicit approval flow:**

- Josh sends `[TYPE: JOSH_APPROVAL]` or replies `approve url fetch` for a specific task id
- Worker re-run with approved external access flag
- Never auto-fetch URLs without recorded approval

---

## P3: Medium-Term

### 11. NotebookLM Conveyor — Promote to Live (Manual)

DryRun schedule verified. When Josh wants fresh NotebookLM corpus:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\notebooklm_conveyor.ps1 -Mode Live
```

Do not enable scheduled Live upload without explicit policy update (private workspace risk).

### 12. Knowledge Pool → Actionable Backlog

Weekly top-3 actionable items from `data\knowledge_pool\`.

### 13. Productize `dispatch_worker.ps1`

Generalize URL intake worker pattern for all typed dispatch types.

---

## If You Can Only Do Three Things

| Priority | Action | Why |
|---|---|---|
| **1** | Josh pastes Upwork URLs → promote URL intake results to leads/proposals | Reuses working pipeline; unblocks business |
| **2** | Sync Escalation Index status & fix Python 3.13 broken launcher | Unblocks execution queue & status tracking pipeline |
| **3** | env_manager.py credentials migration to Credential Manager | Secures plaintext API keys / passwords storage |

---

## Anti-Patterns to Avoid

- Building new scrapers while URL intake loop already exists
- Using Groq as full Hermes agent backend (413 / TPM failure)
- Letting Hermes Lite claim routing without artifacts (overclaim — already fixed once)
- Using `qwen3.5:9b` for routine Ollama queues (too slow per eval)
- Non-Cursor agents editing this file or `PROJECT_ANALYSIS.md`
- Unattended NotebookLM Live upload of full private workspace

---

## Change Log (Synced Updates)

| Date | Update |
|---|---|
| 2026-06-25 | Initial creation from analysis session |
| 2026-06-25 | Synced: typed dispatch, cron throttle, free window partial |
| 2026-06-26 | Synced: Hermes Lite, URL intake worker loop, Ollama eval, NotebookLM conveyor |
| 2026-07-05 | Phase 1-03 Root Cleanup completed. Reorganized legacy scripts, network logs, and HERMES_NOTES.md. Updated docs\INDEX.md and corrected HERMES_NOTES.md governance authority. |
| 2026-07-06 | Created send_task_to_antigravity.ps1 automated handoff script and AGENTOS_ROLE.md integration contract. Passed CopyOnly and Fail-Closed security verification. |

---

## Related Documents

- Project analysis: `archive\Cursor_use\PROJECT_ANALYSIS.md`
- Architecture: `docs\ARCHITECTURE.md`
- Routing: `docs\AGENT_ROUTING_PLAN.md`, `docs\COST_SAVING_ROUTING_PROTOCOL.md`
- Free window: `docs\FREE_CLOUD_WINDOW_POLICY.md`
- Ollama eval: `docs\OLLAMA_MODEL_PRACTICAL_EVALUATION.md`
- NotebookLM: `docs\NOTEBOOKLM_CONVEYOR.md`
- Evidence contract: `docs\EVIDENCE_AND_REPORTING_CONTRACT.md`
- Current snapshot: `current_state.md`
- Change history: `progress_log.md`
