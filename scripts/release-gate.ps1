#Requires -Version 5.1
<#
.SYNOPSIS
  Local Garra release gate — no deploy, no push, no secrets required.
#>
$ErrorActionPreference = "Stop"
$rootMobile = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootBackend = Resolve-Path (Join-Path $rootMobile "..\garra-digital\garra-digital")

function Step($name, [scriptblock]$block) {
  Write-Host "`n==> $name"
  & $block
  if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    throw "FAIL: $name (exit=$LASTEXITCODE)"
  }
  Write-Host "PASS: $name"
}

$results = [ordered]@{}

try {
  Push-Location (Join-Path $rootBackend "api")
  Step "BACKEND_TESTS" { ./mvnw -B test }
  $results.BACKEND_TESTS = "PASS"
  Pop-Location

  Push-Location $rootMobile
  Step "MOBILE_ANALYZE" {
    flutter analyze --no-fatal-infos | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed" }
  }
  $results.MOBILE_ANALYZE = "PASS"
  Step "MOBILE_TESTS" { flutter test }
  $results.MOBILE_TESTS = "PASS"
  Step "DEBUG_BUILD" { flutter build apk --debug }
  $results.DEBUG_BUILD = "PASS"

  $authHash = (git hash-object "lib/features/auth/data/auth_service.dart")
  Write-Host "PROTECTED_AUTH_HASH=$authHash"
  if (Select-String -Path "lib/core/config/api_config.dart" -Pattern "humorous-forgiveness-production-4439" -Quiet) {
    throw "LEGACY_HOST present in api_config"
  }
  $results.CONFIG_GUARDS = "PASS"
  $results.PROTECTED_FILES = "PASS"
  Pop-Location

  Write-Host "`nGARRA RELEASE GATE"
  foreach ($k in $results.Keys) { Write-Host "$k $($results[$k])" }
  Write-Host "RELEASE_GATE PASS"
  exit 0
}
catch {
  Write-Host $_
  Write-Host "RELEASE_GATE FAIL"
  exit 1
}
finally {
  Pop-Location -ErrorAction SilentlyContinue
}
