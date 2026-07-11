[CmdletBinding()]
param([string]$OutputDir)

$ErrorActionPreference = "Stop"
$project = $PSScriptRoot
$root = (Resolve-Path (Join-Path $project "..\..")).Path
if (-not $OutputDir) { $OutputDir = Join-Path $project "dist" }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$compiler = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw "Windows C# compiler not found: $compiler" }
$output = Join-Path $OutputDir "AgentOS Control Center.exe"
& $compiler /nologo /target:winexe /optimize+ /out:$output /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Web.Extensions.dll /reference:Microsoft.VisualBasic.dll (Join-Path $project "Program.cs")
if ($LASTEXITCODE -ne 0) { throw "Control Center compilation failed." }
Write-Output "control_center_build_status=PASS"
Write-Output "output_path=$output"
