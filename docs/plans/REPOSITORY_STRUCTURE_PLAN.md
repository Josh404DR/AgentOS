document_status: phase2a_partial
phase: 1+2A
author: Antigravity IDE
created_at: 2026-07-05
updated_at: 2026-07-05 (Phase 2A static files executed)
note: Phase 2A static file moves completed. Remaining items still pending_josh.

---

SECTION 1 - KEEP_ROOT

AGENTS.md, README.md, current_state.md, progress_log.md, .env, .gitignore,
.git/, .agents/, CLAUDE.md, config/, agents/, dashboard/, data/, docs/,
integrations/, prompts/, scripts/, tests/, workflows/, exports/, logs/, scratch/

---

SECTION 2 - PROJECT_CANDIDATE -> projects\

path                                     | git | ref | risk   | decision
data-quality-audit-toolkit\              | yes |  14 | high   | MOVED -> projects\data-quality-audit-toolkit (2026-07-05)
ecommerce-market-intelligence-dashboard\ | yes |  14 | high   | MOVED -> projects\ecommerce-market-intelligence-dashboard (2026-07-05)
ecommerce-operations-automation-pipeline\| yes |  13 | high   | MOVED -> projects\ecommerce-operations-automation-pipeline (2026-07-05)
josh-resume\                             | yes |   6 | high   | MOVED -> projects\josh-resume (2026-07-05)
josh-resume-portfolio-update\            | no  |   4 | medium | MOVED -> projects\josh-resume-portfolio-update (2026-07-05)
staging_site\                            | no  |   1 | low    | MOVED -> projects\staging_site (2026-07-05)

---

SECTION 3 - TOOLS_CANDIDATE -> tools\

path                  | git | ref | risk   | decision
fetch_threads.py      | no  |   6 | medium | MOVED -> tools\threads\fetch_threads.py (2026-07-05)
scrape_upwork.py      | no  |  18 | high   | MOVED -> tools\upwork\scrape_upwork.py (2026-07-05)
upwork_api_search.py  | no  |   8 | medium | MOVED -> tools\upwork\upwork_api_search.py (2026-07-05)
upwork_capture_auth.py| no  |   5 | medium | MOVED -> tools\upwork\upwork_capture_auth.py (2026-07-05)
clone_threads.bat     | no  |   1 | low    | MOVED -> tools\threads\clone_threads.bat (2026-07-05)
get_ip.ps1            | no  |   1 | low    | MOVED -> tools\network\get_ip.ps1 (2026-07-05)
get_tailscale_ip.ps1  | no  |   1 | low    | MOVED -> tools\network\get_tailscale_ip.ps1 (2026-07-05)
tailscale_login.ps1   | no  |   1 | low    | MOVED -> tools\network\tailscale_login.ps1 (2026-07-05)
temp_commit.sh        | no  |   4 | medium | MOVED -> archive\scripts\temp_commit_legacy.sh (2026-07-05)
README_upwork_api.md  | no  |   1 | low    | MOVED -> tools\upwork\README.md (2026-07-05)

---

SECTION 4 - ARCHIVE_CANDIDATE -> archive\

path                          | git | ref | risk | decision
HERMES_NOTES.md               | no  |  18 | high | MOVED -> data\memory\HERMES_NOTES.md (2026-07-05)
NotebookLM_Necessity_Report.md| no  |   2 | low  | MOVED -> docs\reports\NotebookLM_Necessity_Report.md (2026-07-05)
Cursor_use\                   | no  |   3 | low  | MOVED -> archive\Cursor_use\ (2026-07-05)

---

SECTION 5 - ASSETS_CANDIDATE -> assets\

path              | git | ref | risk   | decision
threads_images\   | no  |   2 | low    | MOVED -> assets\threads_images\ (2026-07-05)
test_threads.png  | no  |   1 | low    | MOVED -> assets\threads\test_threads.png (2026-07-05)
upwork_debug.png  | no  |  12 | medium | MOVED -> assets\upwork\upwork_debug.png (2026-07-05)

---

SECTION 6 - SCRATCH_CANDIDATE -> scratch\

path              | git | ref | risk   | decision
ddg_results.html  | no  |   5 | medium | MOVED -> scratch\captures\ddg_results.html (2026-07-05)
page_source.html  | no  |  12 | medium | MOVED -> scratch\captures\page_source.html (2026-07-05)
upwork_utf8.html  | no  |   9 | medium | MOVED -> scratch\captures\upwork_utf8.html (2026-07-05)
my_ip.txt         | no  |   2 | low    | MOVED -> data\monitoring\network\my_ip.txt (2026-07-05)
tailscale_ip.txt  | no  |   3 | low    | MOVED -> data\monitoring\network\tailscale_ip.txt (2026-07-05)

---

SECTION 7 - REVIEW_REQUIRED (cannot classify without Josh decision)

leads.json
  ref_count: 12
  reason: content unknown; may be business data. MOVED -> data\leads\legacy_leads.json (2026-07-05)

"Get-Process -Name node -ErrorAction.txtrestart_dashbrestart_dashboard.ps1oard.ps1"
  ref_count: 1
  reason: corrupted filename; content confirmed as dashboard restart script (stop node + start uvicorn + npm dev)
  do not rename or move in Phase 1; Josh must approve target name and destination

"josh[CJK-filename]hermes.md"
  ref_count: unknown (filename CJK encoding prevented rg match)
  reason: personal startup memo; Josh must confirm target name and section (docs\ or archive\)

---

END OF PHASE 1 PLAN

---

PHASE 2A RECEIPT - 2026-07-05

item: ddg_results.html
  old_path: E:\AgentOS\ddg_results.html
  new_path: E:\AgentOS\scratch\captures\ddg_results.html
  size: 14294 bytes | size_match: PASS
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only (codex_task OUTPUTs are append-only, not updated)
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\scratch\captures\ddg_results.html' -Destination 'E:\AgentOS\ddg_results.html'

item: page_source.html
  old_path: E:\AgentOS\page_source.html
  new_path: E:\AgentOS\scratch\captures\page_source.html
  size: 345776 bytes | size_match: PASS
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  unresolved: progress_log.md contains historical old-path mentions; append-only, not modified
  page_source_output_path_fixed: true
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\scratch\captures\page_source.html' -Destination 'E:\AgentOS\page_source.html'

item: upwork_utf8.html
  old_path: E:\AgentOS\upwork_utf8.html
  new_path: E:\AgentOS\scratch\captures\upwork_utf8.html
  size: 344272 bytes | size_match: PASS
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  unresolved: progress_log.md contains old path mention (append-only; not modified)
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\scratch\captures\upwork_utf8.html' -Destination 'E:\AgentOS\upwork_utf8.html'

item: test_threads.png
  old_path: E:\AgentOS\test_threads.png
  new_path: E:\AgentOS\assets\threads\test_threads.png
  size: 172008 bytes | size_match: PASS
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\assets\threads\test_threads.png' -Destination 'E:\AgentOS\test_threads.png'

item: threads_images\
  old_path: E:\AgentOS\threads_images\
  new_path: E:\AgentOS\assets\threads_images\
  file_count: 6 | total_bytes: 2032731
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\assets\threads_images' -Destination 'E:\AgentOS\threads_images'

item: NotebookLM_Necessity_Report.md
  old_path: E:\AgentOS\NotebookLM_Necessity_Report.md
  new_path: E:\AgentOS\docs\reports\NotebookLM_Necessity_Report.md
  size: 10430 bytes | size_match: PASS
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  unresolved: data\memory\sync_logs\knowledge_pool_migration\KNOWLEDGE_POOL_MIGRATION_REPORT.md contains old path (historical artifact; not modified)
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\docs\reports\NotebookLM_Necessity_Report.md' -Destination 'E:\AgentOS\NotebookLM_Necessity_Report.md'

---

PHASE 2B RECEIPT - 2026-07-05

item: get_ip.ps1
  old_path: E:\AgentOS\get_ip.ps1
  new_path: E:\AgentOS\tools\network\get_ip.ps1
  SHA-256: B5AF5D409500C04E5B011A9141C54EE96A8B95CE9EEC636D45A14F99EF83EB97
  size: 243 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\network\get_ip.ps1' -Destination 'E:\AgentOS\get_ip.ps1'

item: get_tailscale_ip.ps1
  old_path: E:\AgentOS\get_tailscale_ip.ps1
  new_path: E:\AgentOS\tools\network\get_tailscale_ip.ps1
  SHA-256: CAEE41EBE2654D77E4C2B904959D2CB3F0C52C4478A268F99E63811CB937A540
  size: 73 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\network\get_tailscale_ip.ps1' -Destination 'E:\AgentOS\get_tailscale_ip.ps1'

item: tailscale_login.ps1
  old_path: E:\AgentOS\tailscale_login.ps1
  new_path: E:\AgentOS\tools\network\tailscale_login.ps1
  SHA-256: 6905121E34B42C096F9DE149E1D7A4F3C3C134B685A8023B8499A7555B01E5FF
  size: 157 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\network\tailscale_login.ps1' -Destination 'E:\AgentOS\tailscale_login.ps1'

item: clone_threads.bat
  old_path: E:\AgentOS\clone_threads.bat
  new_path: E:\AgentOS\tools\threads\clone_threads.bat
  SHA-256: 476DDF09CEBEB2865D9432182534E287B2404CA73DE05390993896FF30C45F24
  size: 258 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md only
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\threads\clone_threads.bat' -Destination 'E:\AgentOS\clone_threads.bat'

---

PHASE 2C RECEIPT - 2026-07-05 (UPWORK)

item: scrape_upwork.py
  old_path: E:\AgentOS\scrape_upwork.py
  new_path: E:\AgentOS\tools\upwork\scrape_upwork.py
  SHA-256: AB4ECAD94729F4D09CE92CC31279FE83A5A483042D18714959FE861F7DE47063
  size: 4037 bytes
  references_updated: prompts\context_packs\hermes_ops_v2.md, current_state.md, REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\upwork\scrape_upwork.py' -Destination 'E:\AgentOS\scrape_upwork.py'

item: upwork_api_search.py
  old_path: E:\AgentOS\upwork_api_search.py
  new_path: E:\AgentOS\tools\upwork\upwork_api_search.py
  SHA-256: 81CC0EC2D5C77421C88EC59C38B15ADA9667ADF213B1B9829B9CD1DC492927E3
  size: 19409 bytes
  references_updated: prompts\context_packs\hermes_system_prompt_v2.txt, prompts\context_packs\hermes_system_prompt_v2.md, prompts\context_packs\hermes_ops_v2.md, prompts\context_packs\autonomous_coordination_prompt.md, REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\upwork\upwork_api_search.py' -Destination 'E:\AgentOS\upwork_api_search.py'

item: upwork_capture_auth.py
  old_path: E:\AgentOS\upwork_capture_auth.py
  new_path: E:\AgentOS\tools\upwork\upwork_capture_auth.py
  SHA-256: 0655CB47FE9971FFBD0FAC4A0F8B9FC99C21811879230A4FBF88BB564CE9690E
  size: 8953 bytes
  references_updated: prompts\context_packs\hermes_ops_v2.md, REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\upwork\upwork_capture_auth.py' -Destination 'E:\AgentOS\upwork_capture_auth.py'

item: README_upwork_api.md
  old_path: E:\AgentOS\README_upwork_api.md
  new_path: E:\AgentOS\tools\upwork\README.md
  SHA-256: DD5AFF5F70E28E31D44EF08A7B90E6260F39924736B6261A120B35B312CBB9F3
  size: 3859 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md, tools\upwork\README.md (self references)
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\upwork\README.md' -Destination 'E:\AgentOS\README_upwork_api.md'

item: upwork_debug.png
  old_path: E:\AgentOS\upwork_debug.png
  new_path: E:\AgentOS\assets\upwork\upwork_debug.png
  SHA-256: C1015226D71E1559BAA8286FA721B77489C8AF3D94F4F4A2FAE4745960B9FCA4
  size: 18783 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\assets\upwork\upwork_debug.png' -Destination 'E:\AgentOS\upwork_debug.png'

item: leads.json
  old_path: E:\AgentOS\leads.json
  new_path: E:\AgentOS\data\leads\legacy_leads.json
  SHA-256: 4F53CDA18C2BAA0C0354BB5F9A3ECBE5ED12AB4D8E11BA873C2F11161202B945
  size: 2 bytes
  references_updated: REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\data\leads\legacy_leads.json' -Destination 'E:\AgentOS\leads.json'

---

PHASE 2D RECEIPT - 2026-07-05 (PROJECTS)

item: data-quality-audit-toolkit
  old_path: E:\AgentOS\data-quality-audit-toolkit
  new_path: E:\AgentOS\projects\data-quality-audit-toolkit
  HEAD: 0ef50740052ff0e7c977a2feb11e8ee0111a8fc3
  branch: main
  remote: https://github.com/Josh404DR/data-quality-audit-toolkit.git
  git_status: ?? assets/
  file_count: 94
  total_bytes: 508450
  manifest_summary_hash: 3833782BDA50083BD0FC004759DB3EB30C28542A924800E0958A26C5967F2BE5
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\data-quality-audit-toolkit' -Destination 'E:\AgentOS\data-quality-audit-toolkit'

item: ecommerce-market-intelligence-dashboard
  old_path: E:\AgentOS\ecommerce-market-intelligence-dashboard
  new_path: E:\AgentOS\projects\ecommerce-market-intelligence-dashboard
  HEAD: f22de12268acfd62175d3dd51a7c529b5c640d05
  branch: main
  remote: https://github.com/johnlearningsomesxit/ecommerce-market-intelligence-dashboard.git
  git_status: (clean)
  file_count: 134
  total_bytes: 4742278
  manifest_summary_hash: 11DB77AEBA324C1F3F6F003E935722551C582CE9EB690122D9D31414E32B6A2F
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\ecommerce-market-intelligence-dashboard' -Destination 'E:\AgentOS\ecommerce-market-intelligence-dashboard'

item: ecommerce-operations-automation-pipeline
  old_path: E:\AgentOS\ecommerce-operations-automation-pipeline
  new_path: E:\AgentOS\projects\ecommerce-operations-automation-pipeline
  HEAD: 678a55775539790c9e51182e3fc47fc3ff0703b6
  branch: main
  remote: https://github.com/Josh404DR/ecommerce-operations-automation-pipeline.git
  git_status: (clean)
  file_count: 125
  total_bytes: 3215950
  manifest_summary_hash: 72EDD33EDF66B313462E4610AB2C2A3A1C487B4700F35CD5F35FC7CB1140AE6C
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\ecommerce-operations-automation-pipeline' -Destination 'E:\AgentOS\ecommerce-operations-automation-pipeline'

item: josh-resume
  old_path: E:\AgentOS\josh-resume
  new_path: E:\AgentOS\projects\josh-resume
  HEAD: 3af74d7bb0e79c4871b9f09697cbf5ccaf6c15e0
  branch: main
  remote: https://github.com/Josh404DR/josh-resume.git
  git_status: (clean)
  file_count: 59
  total_bytes: 1683748
  manifest_summary_hash: A72CB2538A490C4580725270DB907C29089C3856E72DF764281EFE6BA3E5269D
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\josh-resume' -Destination 'E:\AgentOS\josh-resume'

item: josh-resume-portfolio-update
  old_path: E:\AgentOS\josh-resume-portfolio-update
  new_path: E:\AgentOS\projects\josh-resume-portfolio-update
  HEAD: N/A (not a git repo)
  branch: N/A
  remote: N/A
  git_status: N/A
  file_count: 24
  total_bytes: 444391
  manifest_summary_hash: 2CDB432F24FA1A7EE29B645160161909106B9A0A1D9594CF922CA09CFD6B39B0
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\josh-resume-portfolio-update' -Destination 'E:\AgentOS\josh-resume-portfolio-update'

item: staging_site
  old_path: E:\AgentOS\staging_site
  new_path: E:\AgentOS\projects\staging_site
  HEAD: N/A (not a git repo)
  branch: N/A
  remote: N/A
  git_status: N/A
  file_count: 0
  total_bytes: 0
  manifest_summary_hash: E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855
  references_updated: current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\projects\staging_site' -Destination 'E:\AgentOS\staging_site'

---

PHASE 2E RECEIPT - 2026-07-05 (FINAL ROOT CLEANUP)

item: fetch_threads.py
  old_path: E:\AgentOS\fetch_threads.py
  new_path: E:\AgentOS\tools\threads\fetch_threads.py
  SHA-256: A9FDA90E746D3DBF214E126C54FDD8038E7DAEDFB108F34A16EAE840C62324D9
  size: 6336 bytes
  references_updated: scripts\threads_url_intake.ps1, docs\THREADS_URL_INTAKE.md, prompts\context_packs\hermes_system_prompt_v2.txt, prompts\context_packs\hermes_system_prompt_v2.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\tools\threads\fetch_threads.py' -Destination 'E:\AgentOS\fetch_threads.py'

item: HERMES_NOTES.md
  old_path: E:\AgentOS\HERMES_NOTES.md
  new_path: E:\AgentOS\data\memory\HERMES_NOTES.md
  SHA-256: BCE2CFFDB407E65BF7EDF70BA3DA37FDC9808DF608685C2442399FFC620BB66C
  size: 4665 bytes
  references_updated: agents\roles\hermes.md, scripts\export_notebooklm_sources.ps1, docs\MEMORY_ARCHITECTURE.md, current_state.md, docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\data\memory\HERMES_NOTES.md' -Destination 'E:\AgentOS\HERMES_NOTES.md'

item: josh這個白癡會忘記怎麼開hermes.md
  old_path: E:\AgentOS\josh這個白癡會忘記怎麼開hermes.md
  new_path: E:\AgentOS\docs\guides\HERMES_STARTUP.md
  SHA-256: 9E0392BE141BCA6162178AC21B85A3E33F36AA78315C09DF8F9DD049EC022158
  size: 1206 bytes
  references_updated: docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\docs\guides\HERMES_STARTUP.md' -Destination 'E:\AgentOS\josh這個白癡會忘記怎麼開hermes.md'

item: Get-Process -Name node -ErrorAction.txtrestart_dashbrestart_dashboard.ps1oard.ps1
  old_path: E:\AgentOS\Get-Process -Name node -ErrorAction.txtrestart_dashbrestart_dashboard.ps1oard.ps1
  new_path: E:\AgentOS\archive\scripts\restart_dashboard_legacy.ps1
  SHA-256: 9459968A901048EB4971E075B957860E3C5446E074D2FF897463B1FB664975B2
  size: 480 bytes
  references_updated: docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\archive\scripts\restart_dashboard_legacy.ps1' -Destination 'E:\AgentOS\Get-Process -Name node -ErrorAction.txtrestart_dashbrestart_dashboard.ps1oard.ps1'

item: temp_commit.sh
  old_path: E:\AgentOS\temp_commit.sh
  new_path: E:\AgentOS\archive\scripts\temp_commit_legacy.sh
  SHA-256: 5BDBF58FAEEBDF0E4F5C150B75C33A9413794597BE9F089AA60C7F03A9E7A82E
  size: 124 bytes
  references_updated: docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\archive\scripts\temp_commit_legacy.sh' -Destination 'E:\AgentOS\temp_commit.sh'

item: my_ip.txt
  old_path: E:\AgentOS\my_ip.txt
  new_path: E:\AgentOS\data\monitoring\network\my_ip.txt
  SHA-256: EF6AD781C72F5232785266C8D605E5BB79E39F9CB02EDF6492D127A4150B0CBC
  size: 18 bytes
  references_updated: tools\network\get_ip.ps1, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\data\monitoring\network\my_ip.txt' -Destination 'E:\AgentOS\my_ip.txt'

item: tailscale_ip.txt
  old_path: E:\AgentOS\tailscale_ip.txt
  new_path: E:\AgentOS\data\monitoring\network\tailscale_ip.txt
  SHA-256: E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855
  size: 0 bytes
  references_updated: tools\network\get_tailscale_ip.ps1, tools\network\tailscale_login.ps1, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\data\monitoring\network\tailscale_ip.txt' -Destination 'E:\AgentOS\tailscale_ip.txt'

item: Cursor_use
  old_path: E:\AgentOS\Cursor_use
  new_path: E:\AgentOS\archive\Cursor_use
  file_count: 3
  total_bytes: 50551
  manifest_summary_hash: B75042517E37219BFD35FA5C00C94AA56BE79B0ED3C7216561733B497A5374B6
  references_updated: docs\INDEX.md, docs\REPOSITORY_STRUCTURE_PLAN.md
  rollback_command: Move-Item -LiteralPath 'E:\AgentOS\archive\Cursor_use' -Destination 'E:\AgentOS\Cursor_use'

