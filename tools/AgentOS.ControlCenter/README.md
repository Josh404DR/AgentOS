# AgentOS Control Center

Build with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\AgentOS.ControlCenter\build.ps1
```

The generated `dist/AgentOS Control Center.exe` reads `config/runtime_registry.json`, refreshes deterministic runtime evidence, opens registered logs, and runs the full local CI gate. Start, stop, and restart are available only when a runtime has an explicit `control` contract. Dashboard control delegates to the existing audited `dashboard/start.ps1`; no process is killed by name alone.

The executable cannot approve governance baselines, delete tasks, stage Git changes, commit, push, or control unregistered processes.
