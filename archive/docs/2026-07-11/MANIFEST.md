# Documentation Archive Manifest

archive_date: 2026-07-11
approval: Josh authorized autonomous execution through Phase 8
operation: reversible `git mv`; no content deleted

| Original path | SHA-256 | Reason | Dependency check | Restore command |
| --- | --- | --- | --- | --- |
| `docs/24H_STABILITY_MONITOR_PLAN.md` | `A9930ED1877ADE4B6D79FAEC0E5A566F3ACC1615D4318AA928A559D0FFB08855` | Superseded by the runtime observability roadmap | Active reference was only the replaced legacy index | `git mv archive/docs/2026-07-11/24H_STABILITY_MONITOR_PLAN.md docs/` |
| `docs/EVIDENCE_HYGIENE_PLAN.md` | `E4D67E61D1E4BB456094F62BED2A0FAC5045B7416A14AC2D36CF5E37D642AA45` | Superseded by the clean-repository roadmap and repository hygiene gate | Active reference was only the replaced legacy index | `git mv archive/docs/2026-07-11/EVIDENCE_HYGIENE_PLAN.md docs/` |
| `docs/HERMES_PROXY_STATUS.md` | `37C6147B265AA6B4677012B3EDB8AEE063A248B2E4B389B138C534249363AB32` | Dated runtime status, not a durable operating contract | No active source references found | `git mv archive/docs/2026-07-11/HERMES_PROXY_STATUS.md docs/` |
| `docs/INDEX.md` | `6E33ADCCC1C88D9544865360EFE00CFCA6A3633FCDA356B433DC78468DE8E824` | Replaced by a concise source-only index | Replaced at the same compatibility path | `git mv archive/docs/2026-07-11/INDEX.md docs/INDEX.legacy.md` |
| `docs/OLLAMA_MODEL_PRACTICAL_EVALUATION.md` | `9A0DD3CC0C5C588ABF4DFC5B7D5FA31910BA1BF770A881CA55F335481B05E2BB` | Dated benchmark evidence | Remaining references are dated reports | `git mv archive/docs/2026-07-11/OLLAMA_MODEL_PRACTICAL_EVALUATION.md docs/` |
| `docs/OLLAMA_SPEED_EVALUATION.md` | `264E192CA950AD991DF94AFCD4B5F8831DA5568BD2D299A4A38628C573CE34E9` | Dated benchmark evidence | Remaining references are dated reports | `git mv archive/docs/2026-07-11/OLLAMA_SPEED_EVALUATION.md docs/` |
| `docs/REPOSITORY_STRUCTURE_PLAN.md` | `33DC1DB8CB113E034051DE5490DE3C20FA08C5FB9C0AD1D3127B06CA9691A6B3` | Superseded by the active Phase 0-8 roadmap | Active reference was only the replaced legacy index; self-reference is historical | `git mv archive/docs/2026-07-11/REPOSITORY_STRUCTURE_PLAN.md docs/` |
| `docs/overnight_report.md` | `EF7725B3C1FC84F5EE422BE9702DCE9B409BC53983C2D174C596F898186E5D8A` | One-time dated report | Remaining reference is a dated inventory report | `git mv archive/docs/2026-07-11/overnight_report.md docs/` |

The old index hash was recalculated from the archived file after the move. All other hashes were captured before migration.
