# AgentOS Control Center

Build with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\AgentOS.ControlCenter\build.ps1
```

The generated `dist/AgentOS Control Center.exe` reads `config/runtime_registry.json`, groups runtimes by startup, on-demand workflow, maintenance, and disabled state, refreshes deterministic evidence, opens registered logs and the latest CI report, and runs the full local CI gate.

Start, stop, and restart are available only when a runtime has an explicit `control` contract. Dashboard control delegates to `dashboard/start.ps1`. Hermes main and Lite use PID receipts and verify executable path, command line, and start time before stopping. Queue control additionally asks for a root dispatch ID and validates its queue-run receipt. No process is killed by executable name alone.

The executable cannot approve governance baselines, delete tasks, stage Git changes, commit, push, or control unregistered processes.
