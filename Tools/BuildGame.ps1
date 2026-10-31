<#
  Packages the game (Win64 Shipping) into C:\Users\boyko\Desktop\Build\PQ_SibJam_v<version>.

  The UnrealClaude engine plugin starts an HTTP server on port 3000 even inside the cook
  commandlet; while the editor is open that port is taken and the cook fails. So the plugin
  is disabled in the .uproject for the duration of the build and the original file is put back
  afterwards, whatever happens.

  Usage:
    .\BuildGame.ps1                 # next version: v0.1, v0.2, ...
    .\BuildGame.ps1 -Version 1.0    # explicit version
#>
param(
    [string]$Version,
    [string]$OutputRoot = 'C:\Users\boyko\Desktop\Build',
    [string]$EngineDir = 'D:\UE_5.7',
    [string]$Config = 'Shipping'
)

$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent $PSScriptRoot
$Uproject = Join-Path $ProjectDir 'PQ_SibJam1126.uproject'
$Backup = "$Uproject.prebuild.bak"
$Prefix = 'PQ_SibJam_v'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# A previous run was killed before it could restore the project file.
if (Test-Path $Backup) {
    Write-Host 'Restoring .uproject left over from an interrupted build'
    Copy-Item $Backup $Uproject -Force
    Remove-Item $Backup -Force
}

if (-not $Version) {
    $last = 0
    if (Test-Path $OutputRoot) {
        Get-ChildItem $OutputRoot -Directory | ForEach-Object {
            if ($_.Name -match "^$([regex]::Escape($Prefix))0\.(\d+)$") { $last = [Math]::Max($last, [int]$Matches[1]) }
        }
    }
    $Version = "0.$($last + 1)"
}
$Target = Join-Path $OutputRoot "$Prefix$Version"
if (Test-Path $Target) { throw "Build folder already exists: $Target" }
$Staging = Join-Path $OutputRoot "_staging_$Prefix$Version"

Write-Host "Building $Prefix$Version -> $Target"

Copy-Item $Uproject $Backup -Force
$exitCode = 1
try {
    $proj = Get-Content $Uproject -Raw | ConvertFrom-Json
    $plugins = @($proj.Plugins | Where-Object { $_.Name -ne 'UnrealClaude' })
    $plugins += [pscustomobject]@{ Name = 'UnrealClaude'; Enabled = $false }
    $proj.Plugins = $plugins
    [IO.File]::WriteAllText($Uproject, ($proj | ConvertTo-Json -Depth 10), $Utf8NoBom)
    Write-Host 'UnrealClaude disabled for the build'

    $uat = Join-Path $EngineDir 'Engine\Build\BatchFiles\RunUAT.bat'
    $editorCmd = Join-Path $EngineDir 'Engine\Binaries\Win64\UnrealEditor-Cmd.exe'
    & $uat BuildCookRun -nop4 -utf8output -nocompileeditor -skipbuildeditor `
        "-project=$Uproject" "-unrealexe=$editorCmd" -platform=Win64 -installed `
        -cook -stage -archive -package -pak -iostore -compressed -prereqs `
        "-archivedirectory=$Staging" "-clientconfig=$Config" -nodebuginfo -build -nocompileuat
    $exitCode = $LASTEXITCODE
}
finally {
    Copy-Item $Backup $Uproject -Force
    Remove-Item $Backup -Force
    Write-Host 'UnrealClaude restored'
}

if ($exitCode -ne 0) {
    if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
    Write-Host "Build FAILED (exit code $exitCode). Log: $env:APPDATA\Unreal Engine\AutomationTool\Logs\$($EngineDir -replace ':','' -replace '\\','+')\Log.txt" -ForegroundColor Red
    exit $exitCode
}

# UAT archives into <dir>\Windows; move that up into the versioned folder.
Move-Item (Join-Path $Staging 'Windows') $Target
Remove-Item $Staging -Recurse -Force
Write-Host "Build OK: $Target" -ForegroundColor Green
