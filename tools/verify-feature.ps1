param([ValidateSet('debug', 'release')][string]$BuildMode = 'debug')
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $workspace
$branch = (git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -notmatch '^[a-z][a-z0-9-]*$') { throw 'Verification requires a named feature branch' }
$deveco = if ($env:DEVECO_HOME) { $env:DEVECO_HOME } else { 'C:\Huawei\DevEco Studio' }
$env:DEVECO_SDK_HOME = Join-Path $deveco 'sdk'
$env:JAVA_HOME = Join-Path $deveco 'jbr'
$env:Path = (Join-Path $deveco 'tools\node') + ';' + $env:Path
$hvigor = Join-Path $deveco 'tools\hvigor\bin\hvigorw.bat'
$output = Join-Path $workspace ('branch-verification\' + $branch)
New-Item -ItemType Directory -Path $output -Force | Out-Null

node --test tools/feature-lib.test.mjs tools/emulator-smoke.test.mjs
if ($LASTEXITCODE -ne 0) { throw 'Tool regression tests failed' }
node tools/check-feature.mjs
if ($LASTEXITCODE -ne 0) { throw 'Feature dependency check failed' }
git diff --check
if ($LASTEXITCODE -ne 0) { throw 'Whitespace check failed' }
$arguments = @('--mode', 'module', '-p', 'module=entry@default', '-p', 'product=default', '-p', "buildMode=$BuildMode", '--no-daemon', '--no-incremental')
& $hvigor assembleHap @arguments *> (Join-Path $output "$BuildMode-build.log")
if ($LASTEXITCODE -ne 0) {
  Get-Content (Join-Path $output "$BuildMode-build.log") -Tail 70
  throw "$branch $BuildMode build failed"
}
Write-Output "$branch $BuildMode HAP build: PASS"

if ($BuildMode -eq 'debug') {
  & $hvigor test @arguments *> (Join-Path $output 'test.log')
  if ($LASTEXITCODE -ne 0) {
    Get-Content (Join-Path $output 'test.log') -Tail 70
    throw "$branch tests failed"
  }
  $result = Join-Path $workspace 'entry\.test\default\intermediates\test\coverage_data\test_result.txt'
  $summary = Get-Content -LiteralPath $result | Select-String '^Tests run:' | Select-Object -Last 1
  if (!$summary -or $summary.Line -notmatch 'Tests run: (\d+), Failure: 0, Error: 0, Pass: (\d+), Ignore: 0' -or $Matches[1] -ne $Matches[2] -or [int]$Matches[1] -le 0) {
    throw "$branch has no passing test result summary"
  }
  Copy-Item -LiteralPath $result -Destination (Join-Path $output 'test_result.txt')
  Write-Output "$branch $($summary.Line)"
}

@{
  branch = $branch
  commit = (git rev-parse HEAD).Trim()
  worktreeDirty = [bool](git status --porcelain)
  buildMode = $BuildMode
  build = 'passed'
  tests = if ($BuildMode -eq 'debug') { $summary.Line } else { 'not run for release' }
  verifiedAt = (Get-Date).ToString('o')
  device = 'not verified'
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output "$BuildMode-result.json") -Encoding utf8
