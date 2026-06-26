1. Use `try-catch` block around `Invoke-Thing`.
2. Catch all exceptions with `catch {}`.
3. Inside `catch`, set `$result = "error"`.
4. After `try-catch`, check if `$result` is still `"success"` and change it to `"error"` if so.
5. Finally, use `Write-Output "status=$result"`.