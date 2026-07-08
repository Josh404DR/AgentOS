# Local LLM Landing Report

- date: 2026-06-29
- status: evidence_backed_roles_defined
- production_brain: false
- final_authority: false

## Evidence Used

- `docs/OLLAMA_MODEL_PRACTICAL_EVALUATION.md`
- `docs/OLLAMA_SPEED_EVALUATION.md`
- `data/ollama_eval/2026-06-26-practical/`
- `data/ollama_eval/2026-06-26-practical-nothink/`
- `data/ollama_eval/2026-06-26-speed-nothink/`

## Landed Roles

| Model | Assigned role | Warm performance | Guardrail |
|---|---|---:|---|
| `llama3.2:3b` | trivial formatting and template transfer | 1.52 s average | no routing or evidence judgment |
| `qwen2.5-coder:7b` | structured task and patch-plan drafts | 2.41 s average | validator required |
| `qwen3:8b` | evidence-hygiene draft | 3.11 s average | `think=false`, validator required |
| `qwen3.5:9b` | long-context condensation only | 10.07 s average | `think=false`, not routine |

## Operational Decision

Local models are conveyor workers, not the AgentOS brain. They may format,
copy, condense, or draft where failure is cheap. They cannot approve external
access, deletion, production readiness, customer messages, security decisions,
or final evidence status.

The highest-value pattern remains:

```text
deterministic intake
  -> local low-risk draft
  -> schema validation
  -> Codex or Claude for judgment and execution
```

## Remaining Work

- Integrate these role assignments into individual production routes only when
  a real repetitive task justifies the added call.
- Do not add Ollama to ordinary chat or the main coordination path.
