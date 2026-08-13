status=completed

Files changed:
- [hermes_system_prompt_v2.txt](E:/AgentOS/prompts/context_packs/hermes_system_prompt_v2.txt)

What changed:
- Replaced the mojibake/corrupted prompt with a clean UTF-8 evidence-based version.
- Updated drift against local evidence:
  - Telegram plugin canonical source is `0.5.0`, not `v0.4.x`.
  - Added current local-file task intake via `scripts\local_file_task_worker.ps1`.
  - Reflected generic URL intake, Threads intake, and `publish_url_knowledge.ps1`.
  - Updated NotebookLM from old bundle assumptions to current five-bundle + independent Knowledge Node model.
  - Preserved safety rules: no external actions, no deletion, no commit/push, no edits to `RECOMMENDATIONS.md` or `PROJECT_ANALYSIS.md`.

Verification:
- Read back target file successfully.
- UTF-8 replacement character count: `0`.
- Line count: `355`.
- Stale-pattern scan found no matches for old `v0.4`, six-bundle, or obsolete NotebookLM wording.
- Confirmed required referenced local files exist: `typed_dispatch.ps1`, plugin source, `local_file_task_worker.ps1`, `publish_url_knowledge.ps1`.
- Confirmed `RECOMMENDATIONS.md` and `PROJECT_ANALYSIS.md` timestamps were unchanged.

Issues:
- Git status could not be used because Git flagged `E:\AgentOS` as dubious ownership under the sandbox user.
- Plugin Python syntax verification could not complete because available Python launchers/venv point to missing WindowsApps Python installs.
- Installed runtime plugin under `%LOCALAPPDATA%` was not inspected because the task boundary said work only inside `E:\AgentOS`; the prompt now explicitly says runtime version must be verified before live claims.

Recommended next step:
- From Josh’s normal Windows session, verify the deployed `%LOCALAPPDATA%\hermes\plugins\agentos-typed-dispatch` version matches canonical `0.5.0`, then fix the broken Python launcher/venv so `py_compile` can validate the plugin.