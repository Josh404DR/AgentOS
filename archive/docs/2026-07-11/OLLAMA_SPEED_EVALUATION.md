# Ollama Speed Evaluation

Updated: 2026-06-26 Asia/Taipei

## Purpose

Measure local Ollama model speed on simulated AgentOS worker tasks.

This is a practical speed test, not a theoretical benchmark.

## Raw Evidence

- Run folder: `data\ollama_eval\2026-06-26-speed-nothink\`
- Raw results: `data\ollama_eval\2026-06-26-speed-nothink\SPEED_RESULTS.json`
- Scorecard: `data\ollama_eval\2026-06-26-speed-nothink\SPEED_SCORECARD.json`

Run settings:

- `DisableThinking=true`
- `num_predict=350`
- `timeout_sec=180`
- models tested: 4
- tasks per model: 5

## Simulated Tasks

1. Tiny key-value formatting.
2. URL intake classification.
3. Short `TASK.md` draft.
4. Long-note organization.
5. Batch classification of 10 items.

## Speed Summary

| Model | First Call | Warm Avg | Avg Tokens/Sec | Practical Speed Role |
|---|---:|---:|---:|---|
| `llama3.2:3b` | 7.67s | 1.52s | 103.64 | fastest cheap formatter |
| `qwen2.5-coder:7b` | 40.14s | 2.41s | 56.61 | best practical worker after warmup |
| `qwen3:8b` | 0.99s | 3.11s | 50.30 | acceptable audit/format worker |
| `qwen3.5:9b` | 19.18s | 10.07s | 22.63 | too slow for routine work |

## Interpretation

### llama3.2:3b

Fastest model.

Observed warm task times:

- URL classify: 0.77s
- task draft: 2.31s
- long organize: 1.53s
- batch classify: 1.45s

Use for:

- trivial formatting
- quick template conversion
- low-risk copy-paste work
- UI/status text cleanup

Do not use for:

- safety logic
- approval decisions
- final evidence judgment

### qwen2.5-coder:7b

Best balance of practical quality and speed after warmup.

Observed warm task times:

- URL classify: 1.24s
- task draft: 5.02s
- long organize: 2.33s
- batch classify: 1.04s

Important caveat:

- First call took 40.14s because of model load.
- After loaded, it is fast enough for AgentOS local worker use.

Use for:

- structured drafts
- fixed-template task generation
- code-adjacent patch plans
- local first-pass work before Codex/Claude

### qwen3:8b

Usable with `think=false`.

Observed warm task times:

- URL classify: 1.18s
- task draft: 4.68s
- long organize: 3.14s
- batch classify: 3.43s

Use for:

- report hygiene drafts
- evidence boundary reminders
- URL intake draft
- medium-quality formatting

### qwen3.5:9b

Too slow for routine use.

Observed warm task times:

- URL classify: 3.13s
- task draft: 11.51s
- long organize: 9.09s
- batch classify: 16.55s

Use only for:

- long-context condensation when latency does not matter

Do not use for:

- high-frequency Telegram intake
- routine formatting
- routing
- repeated task queues

## Recommended Speed-Based Routing

```text
Need fastest trivial formatting:
  llama3.2:3b

Need useful structured local worker:
  qwen2.5-coder:7b

Need evidence-audit draft:
  qwen3:8b with think=false

Need long-context local condensation:
  qwen3.5:9b with think=false, only when waiting is acceptable
```

## Operational Recommendation

Keep `qwen2.5-coder:7b` warm if local worker throughput matters.

If the model is cold, the first request may be slow. For example:

- `qwen2.5-coder:7b` first call: 40.14s
- warm average: 2.41s

For Telegram-facing flows, avoid routing normal chat through cold Ollama unless Josh accepts a delay.

Best default:

```text
Ollama routine local worker = qwen2.5-coder:7b
Ollama fastest formatter = llama3.2:3b
Qwen thinking models = always think=false
```

