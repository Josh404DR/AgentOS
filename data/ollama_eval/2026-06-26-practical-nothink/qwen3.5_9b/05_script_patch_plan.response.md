*   Wrap `Invoke-Thing` inside a `{ }` sub-expression block and pipe it directly into the `-ErrorAction Stop` parameter of `Write-Output`.
*   Alternatively, add `.Exception.Message` or `$?` to the output string only if the previous command succeeded.
*   Use `[Console]::TreatControlCAsInput = $false` (if applicable) combined with explicit error handling via `try/catch` blocks before writing status.
*   Replace `Write-Output "status=success"` with a conditional statement: `"status={0}" -f ($LASTEXITCODE -eq 0 ? 'success' : 'failed')`.
*   Implement `.ErrorAction Stop` on the failing command to ensure non-zero exit codes halt execution before reaching the success message.