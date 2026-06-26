1. Use `try-catch` block around `Invoke-Thing`.
2. Catch non-terminating errors with `-ErrorAction Continue`.
3. Check `$LASTEXITCODE` for success status.
4. Set `$result` based on exit code or error presence.
5. Write output conditionally based on `$result`.