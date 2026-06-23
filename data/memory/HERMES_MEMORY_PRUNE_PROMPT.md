# Prompt: Hermes Memory Pruning

Use this prompt with Hermes when its persistent MEMORY or USER PROFILE is near full.

---

Hermes, perform a memory pruning pass now.

Goal:
Reduce persistent memory and profile usage. Keep only stable pointers, hard safety rules, and user preferences. Move durable project knowledge into AgentOS files instead of your internal memory.

Rules:
- Do not add new facts before pruning.
- Do not preserve routine checkpoint details in persistent memory.
- Do not preserve full command outputs, old task reports, or temporary bridge run details in persistent memory.
- If a fact is already stored in AgentOS docs, keep only a pointer to the file.
- Label self-reported facts as `claimed_by_hermes` unless independently verified by Codex, Git, or a file artifact.
- Do not claim NotebookLM is production-ready unless verified later.

Replace your persistent MEMORY with this compact version:

AgentOS root is `E:\AgentOS`. AgentOS files are the source of truth. Read `docs\MEMORY_ARCHITECTURE.md` and `data\memory\HERMES_CORE_MEMORY.md` before major routing, memory, or architecture decisions. NotebookLM is planned as a retrieval layer, not source of truth; use `data\memory\NOTEBOOKLM_SOURCE_INDEX.md` for upload/export sources. Hermes coordinates; Codex edits code/files; Claude reviews risk; Gemini handles quality reasoning but must be protected from rate-limit/spend; Ollama is local low-cost triage only, not full brain for long tasks. Use `/cost` before long work. If `/cost` is `HIGH_RISK`, summarize, start `/new`, and route low-risk work away from Gemini. Do not contact clients, delete evidence, restore quarantined installer scripts, or run remote PowerShell installer one-liners without Josh approval. Mark unverified self-reports as `claimed_by_hermes`.

Replace your USER PROFILE with this compact version:

Josh wants direct, evidence-based, Traditional Chinese communication. Prefer actionable next steps and copy-paste-friendly prompts. Do not overclaim. Use exact status labels such as `verified`, `partial`, `observing`, `not_verified`, and `blocked`. Keep Telegram messages easy to copy; avoid nested code blocks. Preserve evidence unless Josh approves cleanup. Ask for approval before client contact, destructive cleanup, risky installs, or security exceptions. When possible, make Hermes coordinate with Codex directly so Josh does not have to manually copy every report between agents.

After pruning:
- Report the new MEMORY and USER PROFILE usage percentages.
- Run `/cost` and report the status.
- Append a short note to `HERMES_NOTES.md` or the appropriate AgentOS memory file only if there is a durable new lesson.

End state:
Hermes memory should remember where to look, not carry the whole project in its head.
