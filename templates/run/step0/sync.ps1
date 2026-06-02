param(
    [string]$Config = "config/step0_env.yaml",
    [string]$SshConfig = "run/ssh_config",
    [string]$KnownHosts = "run/known_hosts"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ConfigPath = Join-Path $ProjectRoot $Config
$ConfigText = Get-Content -Raw -Encoding UTF8 $ConfigPath

function Get-Step0Value([string]$Key) {
    $pattern = "(?m)^$([regex]::Escape($Key)):\s*(.+?)\s*$"
    $match = [regex]::Match($ConfigText, $pattern)
    if (-not $match.Success) { throw "Missing config key: $Key" }
    return $match.Groups[1].Value.Trim()
}

$RemoteAlias = Get-Step0Value "remote_alias"
$RemoteRoot = Get-Step0Value "remote_root"
$SshConfigPath = Join-Path $ProjectRoot $SshConfig
$KnownHostsPath = Join-Path $ProjectRoot $KnownHosts

$Items = @(
    "config/step0_env.yaml",
    "config/envs/step0_bootstrap_environment.yml",
    "config/step0_r_packages.tsv",
    "config/step0_conda_fallback.tsv",
    "run/step0/step0_env_lib.sh",
    "run/step0/setup.sh",
    "run/step0/launch.sh",
    "run/step0/check.sh",
    "scripts/setup/install_r_packages_step0.R",
    "scripts/setup/validate_step0.R",
    "docs/setup/STEP0_ENV_SETUP_RUNBOOK.md"
)

$SshOptions = @(
    "-F", $SshConfigPath,
    "-o", "UserKnownHostsFile=$KnownHostsPath",
    "-o", "BatchMode=yes",
    "-o", "ConnectionAttempts=1",
    "-o", "ConnectTimeout=20",
    "-o", "ControlMaster=no",
    "-o", "ControlPath=none"
)

Push-Location $ProjectRoot
try {
    $Stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ArchiveName = "step0_env_setup_$Stamp.tar.gz"
    $ArchivePath = Join-Path ([System.IO.Path]::GetTempPath()) $ArchiveName
    $RemoteArchive = "/tmp/$ArchiveName"

    $Missing = @()
    foreach ($item in $Items) {
        if (-not (Test-Path -LiteralPath $item)) {
            $Missing += $item
        }
    }
    if ($Missing.Count -gt 0) {
        throw ("Step0 sync missing files:`n" + (($Missing | ForEach-Object { " - $_" }) -join "`n"))
    }

    & tar @("-czf", $ArchivePath) @Items
    if ($LASTEXITCODE -ne 0) { throw "tar archive creation failed" }

    & scp @SshOptions $ArchivePath "${RemoteAlias}:$RemoteArchive"
    if ($LASTEXITCODE -ne 0) { throw "scp archive upload failed" }

    Start-Sleep -Seconds 20

    $RemoteExtract = "mkdir -p $RemoteRoot && tar -xzf $RemoteArchive -C $RemoteRoot && rm -f $RemoteArchive"
    & ssh @SshOptions $RemoteAlias $RemoteExtract
    if ($LASTEXITCODE -ne 0) { throw "remote archive extraction failed" }

    Remove-Item -LiteralPath $ArchivePath -Force
}
finally {
    Pop-Location
}
