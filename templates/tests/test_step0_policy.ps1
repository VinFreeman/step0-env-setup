$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$required = @(
    "config/step0_env.yaml",
    "config/envs/step0_bootstrap_environment.yml",
    "config/step0_r_packages.tsv",
    "config/step0_conda_fallback.tsv",
    "run/step0/step0_env_lib.sh",
    "run/step0/setup.sh",
    "run/step0/launch.sh",
    "run/step0/check.sh",
    "run/step0/sync.ps1",
    "scripts/setup/install_r_packages_step0.R",
    "scripts/setup/validate_step0.R",
    "docs/setup/STEP0_ENV_SETUP_RUNBOOK.md"
)

$missing = $required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $projectRoot $_)) }
if ($missing.Count -gt 0) {
    throw ("Missing step0 generated files:`n" + (($missing | ForEach-Object { " - $_" }) -join "`n"))
}

$bootstrap = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot "config/envs/step0_bootstrap_environment.yml")
$lib = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot "run/step0/step0_env_lib.sh")
$setup = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot "run/step0/setup.sh")
$check = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot "run/step0/check.sh")
$installR = Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot "scripts/setup/install_r_packages_step0.R")
$allText = ($required | ForEach-Object { Get-Content -Raw -Encoding UTF8 (Join-Path $projectRoot $_) }) -join "`n"

$errors = @()

foreach ($marker in @("python=3.11", "r-base=4.3", "r-remotes", "r-biocmanager", "r-devtools", "nodefaults")) {
    if ($bootstrap -notmatch [regex]::Escape($marker)) { $errors += "Bootstrap YAML missing $marker" }
}

foreach ($heavy in @("r-seurat", "r-tidyverse", "bioconductor-deseq2", "bioconductor-complexheatmap", "numpy", "pandas", "matplotlib", "opencv", "pyside2", "r-essentials")) {
    if ($bootstrap -match "(?m)^\s*-\s+$([regex]::Escape($heavy))\s*$") { $errors += "Bootstrap YAML must not include $heavy" }
}

foreach ($marker in @("step0_load_config", "step0_run_conda", "CONDA_SOLVER=`"classic`"", "step0_configure_r_makevars", "R_MAKEVARS_USER", "/usr/bin/ar", "/usr/bin/ranlib", "step0_guarded_rm_env_prefix")) {
    if ($lib -notmatch [regex]::Escape($marker)) { $errors += "Library missing marker $marker" }
}

foreach ($marker in @("step0_run_conda create -y -p", "--override-channels", "scripts/setup/install_r_packages_step0.R", "ST_STEP0_R_STATUS_FILE", "ST_STEP0_R_FAILED_FILE", "ST_STEP0_R_PACKAGE_LOG_DIR", "conda_fallback", "python_conda", "scripts/setup/validate_step0.R")) {
    if ($setup -notmatch [regex]::Escape($marker)) { $errors += "Setup missing marker $marker" }
}

foreach ($marker in @("--status-only", "--diagnostics", "LATEST_R_STATUS", "LATEST_R_FAILED", "LATEST_CONDA_FALLBACK", "LATEST_PYTHON_CONDA", "R_PACKAGE_LOG_DIR", "mapfile -t CHILD_PIDS")) {
    if ($check -notmatch [regex]::Escape($marker)) { $errors += "Check missing marker $marker" }
}

foreach ($marker in @("ST_STEP0_R_STATUS_FILE", "extract_missing_dependencies", "dependency_install_started", "dependency_install_finished", "dependency_install_failed", "retry_after_dependencies", "write_failed_packages")) {
    if ($installR -notmatch [regex]::Escape($marker)) { $errors += "R installer missing marker $marker" }
}

$forbiddenPatterns = @(
    ("ST" + "1_"),
    ("st_human" + "_breast_cancer_remote"),
    ("repo.anaconda.com" + "/pkgs/main"),
    ("repo.anaconda.com" + "/pkgs/r"),
    ("conda" + "set")
)

foreach ($forbidden in $forbiddenPatterns) {
    if ($allText -match [regex]::Escape($forbidden)) { $errors += "Generated step0 files contain forbidden marker $forbidden" }
}

if ($errors.Count -gt 0) {
    throw ($errors -join "`n")
}

Write-Host "Generated step0 policy test passed."
