# Avira Review: Hermes install.ps1

Date: 2026-06-22 Asia/Taipei
Executor: Codex

## Trigger

Avira reported and quarantined:

- Item: `install.ps1`
- Detection: `TR/SNH`
- Type: Trojan, according to Avira UI
- Location shown by Avira: `C:\Users\...\hermes-agent\scripts`
- Status: moved to quarantine

## Scope Checked

Codex inspected the Hermes checkout without restoring the quarantined file.

Checked paths:

- `C:\Users\brian\AppData\Local\hermes\hermes-agent\scripts\install.ps1`
- `C:\Users\brian\AppData\Local\hermes\hermes-agent`
- `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent`

Findings:

- The working-tree file `C:\Users\brian\AppData\Local\hermes\hermes-agent\scripts\install.ps1` is missing.
- Git status for that file reports it as deleted: `D scripts/install.ps1`.
- The file still exists in the Hermes git repository at `HEAD:scripts/install.ps1`.
- Both the local Hermes app checkout and the external Hermes checkout contain `scripts/install.ps1` in git.
- Hermes executable still exists at `E:\AI_Projects_Hub\External_AI_Agents\hermes-agent\.venv\Scripts\hermes.exe`.
- A Hermes executable is also on PATH at `C:\Users\brian\AppData\Local\hermes\hermes-agent\venv\Scripts\hermes.exe`.

Repository metadata:

- Hermes repo HEAD inspected: `39c41d0f23a35fdecc143e3cc5ffb2b4dbd3e25d`
- Git tree entry: `100644 blob 481aab276cbf7b3368d6436d9f196373ccc13217 scripts/install.ps1`
- Script size from git HEAD: 2188 lines, 12194 words, 105070 characters

## Content Review

The script is a large Windows bootstrap installer. It performs installer-like actions including:

- Installing or locating `uv`
- Installing or locating Python
- Installing or locating Git / PortableGit
- Installing or locating Node.js
- Installing npm dependencies
- Installing Playwright Chromium
- Updating PATH
- Starting the Hermes gateway if configured

Patterns that likely triggered heuristic antivirus detection:

- `irm ... | iex`
- `powershell -ExecutionPolicy ByPass`
- `Invoke-WebRequest`
- `Invoke-RestMethod`
- `Start-Process`
- Downloading archives and executables
- Expanding downloaded archives
- Installing npm and Python dependencies

Focused checks did not find obvious malicious-control patterns in the inspected script content:

- No `Add-MpPreference`
- No `Set-MpPreference`
- No `DisableRealtimeMonitoring`
- No `EncodedCommand`
- No `FromBase64String`
- No `DownloadString`
- No scheduled task registration detected by the focused pattern search

## Current Assessment

Current status: likely false positive, not fully proven.

Reasoning:

- The detection is against an installer script, not the Hermes runtime executable.
- The script contains multiple behaviors that commonly trigger heuristic detections.
- No obvious antivirus-disable, base64 payload, encoded command, or persistence mechanism was found in the focused review.
- The file was inspected from git HEAD, not restored from quarantine.

This does not prove the script is safe. It means there is not enough evidence from this local review to treat it as confirmed malware.

## Immediate Recommendation

Do not restore or whitelist the quarantined file yet.

Recommended next steps:

1. Keep the quarantined file in Avira quarantine.
2. Continue using the already installed Hermes executable if it runs normally.
3. Avoid running `install.ps1` through `irm | iex`.
4. If reinstall or update is needed, prefer a pinned git checkout and inspect the installer before execution.
5. Optionally submit the file hash or upstream file to Avira for false-positive review.
6. If Avira blocks Hermes runtime files later, pause Hermes automation and review the exact blocked file before allowing it.

## Operational Impact

Short-term impact is limited:

- Hermes runtime appears present.
- AgentOS can continue testing Hermes gateway and Codex bridge using the existing install.
- Reinstall/update workflows that depend on `scripts\install.ps1` may fail until the quarantine issue is resolved.

## Do Not Do Yet

- Do not whitelist the whole Hermes directory.
- Do not restore from quarantine without a deliberate decision.
- Do not rerun the PowerShell remote installer one-liner.
- Do not assume `TR/SNH` is definitely harmless.
- Do not assume Hermes is compromised based only on this detection.

