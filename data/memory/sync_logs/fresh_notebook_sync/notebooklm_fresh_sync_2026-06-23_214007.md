# NotebookLM Sync Log - 2026-06-23_214007

- **Run ID**: 2026-06-23_214007
- **Timestamp**: 2026-06-23T21:40:07.030678
- **Mode**: fresh_notebook_live_sync
- **Notebook Title**: N/A
- **Notebook ID**: N/A
- **Export Dir**: `E:/AgentOS/exports/notebooklm_v1`
- **Files Discovered**: 12
- **Files Uploaded**: 0
- **Files Skipped**: 12
- **Source Count After Sync**: 0
- **Errors**: Traceback (most recent call last):
  File "E:\AgentOS\temp_fresh_sync.py", line 30, in <module>
    asyncio.run(run())
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\asyncio\runners.py", line 44, in run
    return loop.run_until_complete(main)
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\asyncio\base_events.py", line 649, in run_until_complete
    return future.result()
  File "E:\AgentOS\temp_fresh_sync.py", line 7, in run
    async with NotebookLMClient.from_storage() as client:
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\site-packages\notebooklm\client.py", line 967, in __aenter__
    client = await self._build()
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\site-packages\notebooklm\client.py", line 930, in _build
    auth = await AuthTokens.from_storage(Path(path) if path else None, profile=profile)
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\site-packages\notebooklm\_auth\tokens.py", line 192, in from_storage
    ) = await _auth_refresh._fetch_tokens_with_refresh(jar, path, profile, **route_kwargs)
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\site-packages\notebooklm\_auth\refresh.py", line 474, in _fetch_tokens_with_refresh
    csrf, session_id = await _fetch_tokens_with_jar(cookie_jar, storage_path, **route_kwargs)
  File "C:\Users\brian\AppData\Local\Programs\Python\Python310\lib\site-packages\notebooklm\_auth\refresh.py", line 739, in _fetch_tokens_with_jar
    raise ValueError(
ValueError: Authentication expired or invalid. Redirected to: https://accounts.google.com/<redacted>
Run 'notebooklm login' to re-authenticate.
- **Final Status**: fresh_sync_failed

## Files Discovered
- current_state.md
- NOTEBOOK_GUIDE.md
- agents\roles\claude.md
- agents\roles\codex.md
- agents\roles\gemini.md
- agents\roles\hermes.md
- data\memory\HERMES_CORE_MEMORY.md
- docs\AGENT_ROUTING_PLAN.md
- docs\ARCHITECTURE.md
- docs\HERMES_REPORTING_PRINCIPLES.md
- docs\MEMORY_ARCHITECTURE.md
- docs\RESOURCE_INVENTORY.md

## Files Uploaded


---
**Note**: NotebookLM remains retrieval-only; AgentOS files remain source of truth.
