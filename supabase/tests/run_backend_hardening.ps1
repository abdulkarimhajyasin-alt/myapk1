param([switch]$ResetDisposableDatabase)
$ErrorActionPreference = 'Stop'
$dockerEndpoint = ((docker context inspect | ConvertFrom-Json).Endpoints.docker.Host)
if ($LASTEXITCODE -ne 0 -or $dockerEndpoint -notmatch '^(npipe|unix)://') { throw 'Requires a local Docker context' }
if ($env:DOCKER_HOST -and $env:DOCKER_HOST -notmatch '^(npipe|unix)://') { throw 'Remote DOCKER_HOST is forbidden' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$localRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.codex_tmp/maskan-hardening-local'))
if (-not $localRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar)) { throw 'Invalid local workspace' }
$configPath = Join-Path $localRoot 'supabase/config.toml'
if (Test-Path -LiteralPath $configPath) {
    if ((Get-Content -LiteralPath $configPath -Raw) -notmatch 'project_id = "maskan-hardening-local"') { throw 'Unexpected project; refusing to overwrite it' }
}
New-Item -ItemType Directory -Force -Path (Join-Path $localRoot 'supabase/migrations') | Out-Null
$config = [IO.File]::ReadAllText((Join-Path $repoRoot 'supabase/config.toml')).Replace('project_id = "myapkprojekt"','project_id = "maskan-hardening-local"').Replace('5432','5532').Replace('5431','5531')
[IO.File]::WriteAllText($configPath,$config)
Get-ChildItem (Join-Path $repoRoot 'supabase/migrations/*.sql') | Copy-Item -Destination (Join-Path $localRoot 'supabase/migrations') -Force
Copy-Item (Join-Path $repoRoot 'supabase/functions') (Join-Path $localRoot 'supabase') -Recurse -Force
# CLI startup output contains local keys: keep it in the ignored test workspace.
$startupLog = Join-Path $localRoot 'startup.log'
# Native stderr includes ordinary CLI notices; inspect the exit status explicitly.
$ErrorActionPreference = 'Continue'
& npx --yes supabase@2.115.0 start --workdir $localRoot --exclude studio,postgres-meta,logflare,vector,supavisor,imgproxy,edge-runtime *> $startupLog
$startupExit = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($startupExit -ne 0) { throw 'Local startup failed; inspect the ignored startup.log without sharing credentials' }
if ($ResetDisposableDatabase) {
    # Explicit switch resets only this dedicated synthetic-data project.
    & npx --yes supabase@2.115.0 db reset --local --no-seed --workdir $localRoot --yes
    if ($LASTEXITCODE -ne 0) { throw 'Local migration replay failed' }
}
& python (Join-Path $PSScriptRoot 'backend_hardening.py') --workdir $localRoot
if ($LASTEXITCODE -ne 0) { throw 'Backend regression failed' }
