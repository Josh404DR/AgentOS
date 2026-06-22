# AgentOS Resource Inventory

Updated: 2026-06-21 22:33 Asia/Taipei
Owner: Josh Hsu
Purpose: This file is the source of truth for model/tool resources that affect future AgentOS agent configuration.

## Verification Summary

Local verification performed from `E:\AgentOS`.

| Resource | Verified state | Evidence | Operational status |
|---|---|---|---|
| Codex CLI | Installed | `codex --version` -> `codex-cli 0.138.0` | Primary technical execution tool |
| Gemini CLI | Installed | `gemini --version` -> `0.46.0` | Research/summarization/support tool |
| Claude Code CLI | Active via tripartite bridge | `claude auth status` -> `loggedIn: true` | Active Inspector via tripartite bridge for tested review handoffs |
| Claude Pro subscription | Verified via CLI | `claude auth status` | Pro quota available for CLI and manual use |
| Perplexity subscription | User-reported | Josh reports active subscription | Useful for research; no local AgentOS CLI/API integration verified |
| Ollama | Installed | `ollama list` succeeded | Local fallback/small model pool |
| Antigravity IDE desktop subscription | User-reported | Josh reports subscribed desktop usage quota | Manual IDE resource; no AgentOS CLI/API integration verified |
| Perplexity IDE | User-reported | Josh reports available IDE resource | Manual research/coding assistant; no AgentOS automation verified |
| VSCode + Cline free | User-reported | Josh reports available free-tier resource | Manual IDE/agent resource; no AgentOS automation verified |
| Cursor free quota | User-reported | Josh reports available free quota | Manual IDE coding resource; no AgentOS automation verified |

## Ollama Local Models

Verified with `ollama list`:

| Model | Size | Recommended use |
|---|---:|---|
| `qwen3:8b` | 5.2 GB | Local general reasoning, drafting, lightweight triage |
| `qwen2.5-coder:7b` | 4.7 GB | Local code explanation, small script drafts, fallback code review |
| `qwen3.5:9b` | 6.6 GB | Local reasoning fallback when quality matters more than speed |
| `llama3.2:3b` | 2.0 GB | Fast local classification, rough summaries, low-stakes preprocessing |

## Recommended Agent Configuration

### Hermes

Default role: coordinator, Telegram brain, lead workflow owner.

Recommended resource stack:

1. Gemini API through Hermes config for proposal-quality reasoning, lead
   analysis, and high-value planning.
2. Ollama for low-risk Telegram status replies, monitoring checkpoints,
   classification, formatting, and durable-note triage.
3. Gemini CLI for manual research/summarization support when Hermes needs a
   second pass.
4. Perplexity subscription for current web research and source discovery, used
   manually or through a future verified integration.

Hermes should not use Codex/Claude directly for client-facing commitments. Hermes can ask Josh to dispatch a technical packet to Codex.

Rate-limit policy:

- If Gemini rate-limits Hermes, switch the Telegram brain to Ollama with
  `/model ollama`.
- While on Ollama, keep Hermes in low-risk modes: Operator Interface,
  Watchtower / Monitor, Notes Curator, and simple routing drafts.
- Defer proposal-quality writing and business-critical lead analysis until
  Gemini is available again, unless Josh explicitly approves the lower-quality
  fallback.
- Resume normal mode with `/model gemini-flash` and verify with
  `/model status`.

### Codex

Default role: technical execution specialist.

Recommended resource stack:

1. Codex CLI as the primary implementation runner.
2. Claude Code CLI as an optional manual second-opinion/code-review resource after the workflow is explicitly designed.
3. Ollama coder models for small local drafts or fallback analysis, not final authority.

Codex should continue writing `OUTPUTS\RESULT.md` for task packets.

### Gemini

Default role: research, summarization, proposal second opinion, quota fallback support.

Recommended resource stack:

1. Gemini CLI for ad hoc summaries and lead/proposal review.
2. Hermes Gemini API configuration for scheduled Hermes work.
3. Perplexity for current web/source-oriented research when needed.

Gemini output should be folded back into Hermes-managed files and should not become a separate state store.

### Claude

Current state:

- Claude Code CLI is active and verified through the `hermes_tripartite_bridge.ps1`.
- Claude Pro subscription is verified via CLI auth status.

Recommended role:

- **Inspector**: High-assurance technical review of Codex output.
- **Architecture Critique**: Complex reasoning about system design.
- **Second Opinion**: Final safety check before destructive or client-facing actions.
- Use `scripts/hermes_tripartite_bridge.ps1` for automated coordination.

### Perplexity

Current state:

- Subscription is user-reported.
- No local CLI/API integration has been verified inside AgentOS.

Recommended role for now:

- Current market/client/tool research.
- Lead background research.
- Competitive/reference discovery.
- Do not treat Perplexity output as final unless citations/sources are captured in the relevant artifact.

### Antigravity IDE Desktop

Current state:

- Desktop subscription/usage quota is user-reported.
- No AgentOS automation interface has been verified.

Recommended role for now:

- Manual coding/IDE resource when Josh wants to spend desktop quota.
- Not part of Hermes automated orchestration until there is a tested CLI/API/workflow handoff.

### Other Manual IDE Resources

Current state:

- Perplexity IDE is user-reported.
- VSCode + Cline free is user-reported.
- Cursor free quota is user-reported.
- No AgentOS automation interface has been verified for these resources.

Recommended role for now:

- Manual coding/research/review support.
- Useful for interactive work when Josh chooses to spend free or subscribed quota.
- Outputs should be copied into tracked AgentOS artifacts if they affect decisions.
- Not part of Hermes automated orchestration until a tested CLI/API/workflow handoff exists.

## Routing Rules

Use the cheapest reliable resource that fits the task:

- Local Ollama: low-risk categorization, rough summaries, private/offline drafts.
- Gemini: bulk reasoning, lead summaries, proposal second opinions.
- Perplexity: current web research with sources.
- Codex: repo edits, scripts, tests, debugging, implementation artifacts.
- Claude: automated high-assurance review (tripartite bridge) or manual complex reasoning.
- Antigravity / Perplexity IDE / VSCode Cline / Cursor: manual IDE work, not yet automated.
Escalate resource choice when:

- A proposal depends on technical feasibility: create a Codex task packet.
- Current market/client facts matter: use Perplexity or another source-capturing research path.
- A codebase change is high risk: use Codex first, optionally ask Claude for review.
- Quota/cost pressure appears: use Gemini/Ollama for low-risk analysis, keep Codex/Claude for high-value work.

## Current Non-Goals

- Do not build a new multi-agent framework around these resources yet.
- Do not make Claude, Perplexity, Antigravity, Perplexity IDE, VSCode Cline, or Cursor automatic workers until their handoff paths are tested.
- Do not route client-facing messages directly through any model without Josh approval.
- Do not assume a subscription equals API or CLI automation access.
