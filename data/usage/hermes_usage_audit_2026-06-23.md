# Hermes Usage Audit - 2026-06-23

## Scope
- Generated: 2026-06-23 02:19:18 +0800
- Source DB: `C:\Users\brian\AppData\Local\hermes\state.db`
- Privacy: message content was not read; this report uses session metadata and token counters only.

## Summary
- All-time sessions: 96
- All-time non-cache tokens: 14,384,648
- All-time total tokens including cache reads: 71,364,474
- Sessions on 2026-06-23: 1
- 2026-06-23 non-cache tokens: 0
- 2026-06-23 total tokens including cache reads: 0

## Routing Signal
- Ollama-route candidates: 8 sessions
- Ollama-route candidate total tokens: 19,047
- Classification is heuristic. Use it to choose what to inspect next, not as final billing truth.

## By Provider / Model
| Provider / Model | Sessions | Non-cache tokens | Cache read | Total tokens | Cost |
| --- | --- | --- | --- | --- | --- |
| gemini / gemini-3-flash-preview | 68 | 9,667,747 | 56,979,826 | 66,647,573 | $0.0000 |
| gemini / gemini-2.0-flash | 14 | 4,716,901 | 0 | 4,716,901 | $0.0000 |
| (blank) / anthropic/claude-opus-4.6 | 3 | 0 | 0 | 0 | $0.0000 |
| (blank) / gemini-1.5-pro | 1 | 0 | 0 | 0 | $0.0000 |
| (blank) / claude-sonnet-4-6 | 3 | 0 | 0 | 0 | $0.0000 |
| (blank) / gemini-3-flash-preview | 6 | 0 | 0 | 0 | $0.0000 |
| (blank) / openai/gpt-5.3-codex | 1 | 0 | 0 | 0 | $0.0000 |

## By Source
| Source | Sessions | Non-cache tokens | Cache read | Total tokens | Cost |
| --- | --- | --- | --- | --- | --- |
| telegram | 15 | 11,082,955 | 51,546,183 | 62,629,138 | $0.0000 |
| cli | 64 | 2,473,378 | 4,262,574 | 6,735,952 | $0.0000 |
| cron | 17 | 828,315 | 1,171,069 | 1,999,384 | $0.0000 |

## By Work Type
| Work Type | Sessions | Non-cache tokens | Cache read | Total tokens | Cost |
| --- | --- | --- | --- | --- | --- |
| telegram_heavywork | 10 | 11,063,908 | 51,546,183 | 62,610,091 | $0.0000 |
| tool_heavy_work | 32 | 2,450,914 | 4,340,171 | 6,791,085 | $0.0000 |
| scheduled_tool_work | 8 | 617,541 | 837,281 | 1,454,822 | $0.0000 |
| unclassified | 28 | 233,238 | 256,191 | 489,429 | $0.0000 |
| telegram_lightwork | 5 | 19,047 | 0 | 19,047 | $0.0000 |
| unmeasured_or_empty | 10 | 0 | 0 | 0 | $0.0000 |
| scheduled_lightwork | 3 | 0 | 0 | 0 | $0.0000 |

## By Routing Recommendation
| Recommendation | Sessions | Non-cache tokens | Cache read | Total tokens | Cost |
| --- | --- | --- | --- | --- | --- |
| keep_gemini_if_quality_needed | 10 | 11,063,908 | 51,546,183 | 62,610,091 | $0.0000 |
| keep_gemini_or_delegate | 32 | 2,450,914 | 4,340,171 | 6,791,085 | $0.0000 |
| review_before_routing | 8 | 617,541 | 837,281 | 1,454,822 | $0.0000 |
| inspect_if_high_token | 28 | 233,238 | 256,191 | 489,429 | $0.0000 |
| route_to_ollama_candidate | 8 | 19,047 | 0 | 19,047 | $0.0000 |
| needs_instrumentation_check | 10 | 0 | 0 | 0 | $0.0000 |

## Top Token Sessions
| Session | Started | Source | Provider | Model | Messages | Tools | Non-cache | Cache read | Total | Work type | Recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 20260622_061850_ddc06c87 | 2026-06-22 06:18:50 +0800 | telegram | gemini | gemini-3-flash-preview | 344 | 132 | 6,118,081 | 43,701,420 | 49,819,501 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260620_120640_f28042f7 | 2026-06-20 12:06:40 +0800 | telegram | gemini | gemini-3-flash-preview | 162 | 74 | 792,109 | 4,906,942 | 5,699,051 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260621_230744_c51f2a2f | 2026-06-21 23:07:44 +0800 | telegram | gemini | gemini-3-flash-preview | 172 | 86 | 564,684 | 2,726,457 | 3,291,141 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260523_145723_f3a54033 | 2026-05-23 14:57:23 +0800 | telegram | gemini | gemini-2.0-flash | 198 | 41 | 3,230,387 | 0 | 3,230,387 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260523_132215_a626ed | 2026-05-23 13:22:16 +0800 | cli | gemini | gemini-2.0-flash | 47 | 23 | 897,011 | 0 | 897,011 | tool_heavy_work | keep_gemini_or_delegate |
| cron_d00fbf284738_20260622_080038 | 2026-06-22 08:00:38 +0800 | cron | gemini | gemini-3-flash-preview | 51 | 27 | 173,797 | 674,794 | 848,591 | scheduled_tool_work | review_before_routing |
| 20260622_075620_886c85 | 2026-06-22 07:56:22 +0800 | cli | gemini | gemini-3-flash-preview | 51 | 25 | 127,282 | 592,281 | 719,563 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_095656_801909 | 2026-06-22 09:56:57 +0800 | cli | gemini | gemini-3-flash-preview | 41 | 21 | 108,119 | 487,636 | 595,755 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_080153_46a32a | 2026-06-22 08:01:53 +0800 | cron | gemini | gemini-3-flash-preview | 103 | 50 | 185,818 | 333,788 | 519,606 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_101001_8b071d | 2026-06-22 10:10:02 +0800 | cli | gemini | gemini-3-flash-preview | 20 | 9 | 53,800 | 301,485 | 355,285 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_120315_4b2fd8 | 2026-06-22 12:03:15 +0800 | cli | gemini | gemini-3-flash-preview | 32 | 15 | 64,008 | 259,211 | 323,219 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_113014_ed8521 | 2026-06-22 11:30:15 +0800 | cli | gemini | gemini-3-flash-preview | 23 | 11 | 117,408 | 154,423 | 271,831 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_121001_32c687 | 2026-06-22 12:10:01 +0800 | cli | gemini | gemini-3-flash-preview | 24 | 11 | 47,206 | 219,224 | 266,430 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_115702_87a9c1 | 2026-06-22 11:57:02 +0800 | cli | gemini | gemini-3-flash-preview | 24 | 11 | 79,062 | 186,739 | 265,801 | tool_heavy_work | keep_gemini_or_delegate |
| 20260622_095312_91b530 | 2026-06-22 09:53:12 +0800 | cli | gemini | gemini-3-flash-preview | 24 | 11 | 58,688 | 202,958 | 261,646 | tool_heavy_work | keep_gemini_or_delegate |
| 20260620_004536_4ffe2c26 | 2026-06-20 00:45:36 +0800 | telegram | gemini | gemini-3-flash-preview | 21 | 8 | 76,612 | 154,588 | 231,200 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260622_111739_672677 | 2026-06-22 11:17:40 +0800 | cli | gemini | gemini-3-flash-preview | 20 | 9 | 52,352 | 154,153 | 206,505 | tool_heavy_work | keep_gemini_or_delegate |
| cron_c22498762626_20260622_075541 | 2026-06-22 07:55:42 +0800 | cron | gemini | gemini-3-flash-preview | 14 | 7 | 137,154 | 65,226 | 202,380 | scheduled_tool_work | review_before_routing |
| 20260523_154017_14559c | 2026-05-23 15:40:18 +0800 | telegram | gemini | gemini-2.0-flash | 30 | 14 | 194,436 | 0 | 194,436 | telegram_heavywork | keep_gemini_if_quality_needed |
| 20260622_100244_e5956b | 2026-06-22 10:02:44 +0800 | cli | gemini | gemini-3-flash-preview | 16 | 8 | 31,737 | 146,382 | 178,119 | tool_heavy_work | keep_gemini_or_delegate |

## Initial Action Items
- Keep `/model ollama` for Watchtower, Notes Curator, formatting, and low-risk routing drafts.
- Keep Gemini for proposal-quality writing, lead analysis, and high-impact planning.
- Inspect top token sessions before changing cron jobs; large cache-read totals may be context reuse rather than fresh billing.
- Add explicit Hermes mode tags to future sessions if exact work-type accounting is needed.
