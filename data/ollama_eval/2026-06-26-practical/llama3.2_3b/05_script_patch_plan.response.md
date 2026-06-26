Here is a minimal patch plan:

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

• **Use Error Handling with Return Value**: Use the `return` keyword to return a non-zero value if an error occurs.

```powershell
$result = Invoke-Thing
if ($result -eq $null) {
    Write-Output "status=failure"
    return 1
} else {
    Write-Output "status=success"
}
```

• **Use PowerShell's Built-in Error Handling**: Use the `ErrorAction` parameter to specify how errors should be handled.

```powershell
$result = Invoke-Thing -ErrorAction Stop
if ($result -eq $null) {
    Write-Output "status=failure"
} else {
    Write-Output "status=success"
}
```

Note: The above examples assume that `Invoke-Thing` is a cmdlet or function that returns an object with an `ExitCode` property.