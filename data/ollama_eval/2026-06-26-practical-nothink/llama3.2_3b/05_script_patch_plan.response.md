Here's a minimal patch plan:

• **Use Try-Catch Block**: Wrap the `Invoke-Thing` call in a try-catch block to catch any non-terminating errors.

```powershell
try {
    $result = Invoke-Thing
} catch [System.Management.Automation.RuntimeException] {
    Write-Output "status=failure"
    exit 1
}
```

• **Check Error Code**: Check the error code returned by `Invoke-Thing` to determine if it's a non-terminating error.

```powershell
$result = Invoke-Thing
if ($result.ErrorInfo.ExitCode -ne 0) {
    Write-Output "status=failure"
} else {
    Write-Output "status=success"
}
```

• **Use Error Handling with Exit Code**: Use the `Exit` cmdlet to exit the script with a non-zero code if an error occurs.

```powershell
$result = Invoke-Thing
if ($result.ExitCode -ne 0) {
    Write-Output "status=failure"
    exit $result.ExitCode
}
```

• **Use PowerShell's Built-in Error Handling**: Use the `Error` cmdlet to catch and handle errors in a more elegant way.

```powershell
$result = Invoke-Thing
if ($PSError[0].Message -like "*non-terminating error*") {
    Write-Output "status=failure"
} else {
    Write-Output "status=success"
}
```

• **Use PowerShell's Built-in Exit Code**: Use the `Exit` cmdlet with a non-zero code to indicate failure.

```powershell
$result = Invoke-Thing
if ($result.ExitCode -ne 0) {
    Write-Output "status=failure"
    exit $result.ExitCode
}
```

Note: The exact PowerShell concepts used may vary depending on the specific requirements and error handling mechanisms in use.