# Installs the DartNative IDE pub fix into a DartNative SDK (Windows).
# Usage: powershell -ExecutionPolicy Bypass -File .\install.ps1 [C:\path\to\dartnative-sdk]
param([string]$Sdk = "")
$ErrorActionPreference = "Stop"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
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
$Applied = $false
# Each fix is one patch, applied in order and skipped when its marker is already
# in the tool sources. Fix 3 is made on top of Fix 2.
function Apply-Fix([string]$Name, [string]$PatchFile, [string]$Marker) {
  $Patch = Join-Path $Here $PatchFile
  if (Select-String -Path $Pub -Pattern $Marker -Quiet) { Write-Host "$Name: already installed."; return }
  git -C $Sdk apply --check $Patch
  if ($LASTEXITCODE -ne 0) {
    Write-Error "$Name does not apply to this SDK version. It was made for DartNative SDK 113c27aacb2."
  }
  git -C $Sdk apply $Patch
  Write-Host "$Name: patched."
  $script:Applied = $true
}
Apply-Fix "Fix 2 (DevTools)" "dn-ide-devtools.patch" "_registerIdeDartSdk"
Apply-Fix "Fix 3 (stock Flutter hand-off)" "dn-stock-flutter-handoff.patch" "_dependsOnDartNative"
if (-not $Applied) { Write-Host "Nothing to do."; exit 0 }
Write-Host "Patched. Rebuilding the dn tool (about 30 seconds)..."
Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Sdk "bin\cache\flutter_tools.snapshot"), (Join-Path $Sdk "bin\cache\flutter_tools.stamp")
& (Join-Path $Sdk "bin\dn.bat") --version | Out-Null
Write-Host ""
Write-Host "Done. 'dn create' and 'dn pub get' / 'dn run' now write the IDE's Dart SDK files"
Write-Host "(reopen an existing project once), and the SDK's flutter.bat hands a project that"
Write-Host "does not depend on dartnative to stock Flutter instead of editing its pubspec."
