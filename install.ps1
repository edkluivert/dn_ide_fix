# Installs the DartNative IDE pub fix into a DartNative SDK (Windows).
# Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1 [C:\path\to\dartnative-sdk]
param([string]$Sdk = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Patch = Join-Path $Here "dn-ide-pub-overrides.patch"

if ($Sdk -eq "") {
  $dn = Get-Command dn.bat -ErrorAction SilentlyContinue
  if (-not $dn) { $dn = Get-Command dn -ErrorAction SilentlyContinue }
  if (-not $dn) { Write-Error "'dn' is not on PATH. Pass the SDK folder: .\install.ps1 C:\path\to\dartnative-sdk" }
  $Sdk = Split-Path -Parent (Split-Path -Parent $dn.Source)
}
$Sdk = $Sdk.TrimEnd('\')
$Pub = Join-Path $Sdk "packages\flutter_tools\lib\src\dart\pub.dart"
if (-not (Test-Path (Join-Path $Sdk "bin\dn.bat")) -or -not (Test-Path $Pub)) {
  Write-Error "$Sdk does not look like a DartNative SDK."
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error "git is required." }

Write-Host "SDK: $Sdk"
if (Select-String -Path $Pub -Pattern "_writePubspecOverridesFile" -Quiet) {
  Write-Host "Already installed. Nothing to do."; exit 0
}
git -C $Sdk apply --check $Patch
if ($LASTEXITCODE -ne 0) {
  Write-Error "The patch does not apply to this SDK version. It was made for DartNative 3.45.0-0.1.pre (framework 80edbf105e)."
}
git -C $Sdk apply $Patch
Write-Host "Patched. Rebuilding the dn tool (about 30 seconds)..."
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Sdk "bin\cache\flutter_tools.snapshot"), (Join-Path $Sdk "bin\cache\flutter_tools.stamp")
& (Join-Path $Sdk "bin\dn.bat") --version | Out-Null
Write-Host ""
Write-Host "Done. Every 'dn pub get' or 'dn run' now writes pubspec_overrides.yaml so"
Write-Host "Android Studio / VS Code / CI pub get resolves the DartNative packages."
Write-Host "In an existing project, run 'dn pub get' once."
