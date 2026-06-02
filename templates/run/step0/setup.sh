#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-${PWD}}"
CONFIG="${2:-config/step0_env.yaml}"
cd "$ROOT"
source run/step0/step0_env_lib.sh
step0_load_config "$CONFIG"

STAMP="${SETUP_STAMP:-$(date '+%Y%m%d_%H%M%S')}"
LOG_DIR="$ROOT/logs/setup"
LOG_FILE="$LOG_DIR/setup_${STEP0_ENV_NAME}_${STAMP}.log"
STATUS_FILE="$LOG_DIR/setup_${STEP0_ENV_NAME}_${STAMP}.status.tsv"
MANIFEST="$LOG_DIR/setup_${STEP0_ENV_NAME}_${STAMP}.manifest.tsv"
R_STATUS_FILE="$LOG_DIR/${STEP0_ENV_NAME}_r_packages_${STAMP}.status.tsv"
R_FAILED_FILE="$LOG_DIR/${STEP0_ENV_NAME}_r_packages_${STAMP}.failed.tsv"
R_PACKAGE_LOG_DIR="$LOG_DIR/${STEP0_ENV_NAME}_r_package_logs_${STAMP}"
CONDA_FALLBACK_STATUS="$LOG_DIR/${STEP0_ENV_NAME}_conda_fallback_${STAMP}.status.tsv"
PYTHON_CONDA_STATUS="$LOG_DIR/${STEP0_ENV_NAME}_python_conda_${STAMP}.status.tsv"
STEP0_CONDARC="$ROOT/config/condarc_${STEP0_ENV_NAME}.yml"
STEP0_CONDA_CLEAN_HOME="$ROOT/tmp/conda_home_${STEP0_ENV_NAME}"
STEP0_CONDA_PKGS_DIRS="$ROOT/tmp/conda_pkgs_${STEP0_ENV_NAME}"
MAKEVARS="$ROOT/tmp/${STEP0_ENV_NAME}_setup_Makevars"

export STEP0_CONDARC STEP0_CONDA_CLEAN_HOME STEP0_CONDA_PKGS_DIRS

mkdir -p "$LOG_DIR" "$ROOT/tmp" "$(dirname "$STEP0_ENV_PREFIX")"
exec > >(tee -a "$LOG_FILE") 2>&1

record_status() {
  step0_record_status "$STATUS_FILE" "$@"
}

write_manifest() {
  {
    printf "key\tvalue\n"
    printf "started_at\t%s\n" "$(date '+%F %T %Z')"
    printf "root\t%s\n" "$ROOT"
    printf "config\t%s\n" "$CONFIG"
    printf "env_name\t%s\n" "$STEP0_ENV_NAME"
    printf "env_prefix\t%s\n" "$STEP0_ENV_PREFIX"
    printf "conda_dir\t%s\n" "$STEP0_CONDA_DIR"
    printf "conda_solver\tclassic\n"
    printf "log_file\t%s\n" "$LOG_FILE"
    printf "status_file\t%s\n" "$STATUS_FILE"
    printf "r_status_file\t%s\n" "$R_STATUS_FILE"
    printf "r_failed_file\t%s\n" "$R_FAILED_FILE"
    printf "r_package_log_dir\t%s\n" "$R_PACKAGE_LOG_DIR"
    printf "conda_fallback_status\t%s\n" "$CONDA_FALLBACK_STATUS"
    printf "python_conda_status\t%s\n" "$PYTHON_CONDA_STATUS"
    printf "r_makevars_user\t%s\n" "$MAKEVARS"
  } > "$MANIFEST"
}

mapfile -t STEP0_CHANNEL_ARGS < <(step0_channel_args)
STEP0_BOOTSTRAP_SPECS=(
  "python=3.11"
  "pip"
  "pyyaml"
  "r-base=4.3"
  "r-remotes"
  "r-biocmanager"
  "r-devtools"
  "r-yaml"
  "r-jsonlite"
  "r-matrix"
  "r-rcpp"
  "r-curl"
  "r-openssl"
  "r-xml2"
)

step0_write_condarc "$STEP0_CONDARC" "$STEP0_CONDA_CLEAN_HOME" $STEP0_CONDA_CHANNELS
write_manifest

if [ ! -x "$STEP0_CONDA_DIR/bin/conda" ]; then
  record_status "conda" "failed" "missing_account_conda:$STEP0_CONDA_DIR/bin/conda"
  exit 1
fi

record_status "conda" "info" "$("$STEP0_CONDA_DIR/bin/conda" --version)"
step0_run_conda config --show-sources || true
step0_run_conda config --show channels channel_alias custom_channels channel_priority show_channel_urls solver || true

if [ -d "$STEP0_ENV_PREFIX" ] && [ "$STEP0_FORCE_RECREATE" = "true" ]; then
  record_status "conda_env" "remove_prefix_started" "$STEP0_ENV_PREFIX"
  step0_guarded_rm_env_prefix "$STEP0_ENV_PREFIX"
  record_status "conda_env" "remove_prefix_finished" "$STEP0_ENV_PREFIX"
fi

if [ -d "$STEP0_ENV_PREFIX" ] && [ ! -x "$STEP0_ENV_PREFIX/bin/R" ]; then
  record_status "conda_env" "remove_incomplete_prefix_started" "$STEP0_ENV_PREFIX"
  step0_guarded_rm_env_prefix "$STEP0_ENV_PREFIX"
  record_status "conda_env" "remove_incomplete_prefix_finished" "$STEP0_ENV_PREFIX"
fi

if [ -x "$STEP0_ENV_PREFIX/bin/R" ]; then
  record_status "conda_env" "exists" "$STEP0_ENV_PREFIX"
else
  record_status "conda_env" "create_started" "$STEP0_ENV_PREFIX"
  step0_run_conda create -y -p "$STEP0_ENV_PREFIX" --override-channels "${STEP0_CHANNEL_ARGS[@]}" "${STEP0_BOOTSTRAP_SPECS[@]}"
  record_status "conda_env" "create_finished" "$STEP0_ENV_PREFIX"
fi

source "$STEP0_CONDA_DIR/etc/profile.d/conda.sh"
conda activate "$STEP0_ENV_PREFIX"
step0_configure_r_makevars "$MAKEVARS"
record_status "r_makevars" "configured" "$R_MAKEVARS_USER"

record_status "r_packages" "started" "$R_STATUS_FILE"
export ST_STEP0_R_STATUS_FILE="$R_STATUS_FILE"
export ST_STEP0_R_FAILED_FILE="$R_FAILED_FILE"
export ST_STEP0_R_PACKAGE_LOG_DIR="$R_PACKAGE_LOG_DIR"
export ST_STEP0_R_PACKAGE_PLAN="$STEP0_R_PACKAGE_PLAN"
export ST_STEP0_INSTALL_NCPUS="$STEP0_INSTALL_NCPUS"
export ST_STEP0_MAX_DEPENDENCY_DEPTH="$STEP0_MAX_DEPENDENCY_DEPTH"
export ST_STEP0_CRAN_MIRROR="$STEP0_CRAN_MIRROR"
export ST_STEP0_BIOC_MIRROR="$STEP0_BIOC_MIRROR"
Rscript scripts/setup/install_r_packages_step0.R || record_status "r_packages" "failed_nonfatal" "$R_FAILED_FILE"
record_status "r_packages" "finished" "$R_STATUS_FILE"

load_conda_fallback_spec() {
  local pkg="$1"
  awk -F '\t' -v pkg="$pkg" 'NR > 1 && $1 == pkg { print $2; exit }' "$STEP0_CONDA_FALLBACK_MAP"
}

printf "time\tpackage\tstatus\tspec\tlog_file\n" > "$CONDA_FALLBACK_STATUS"
if [ -s "$R_FAILED_FILE" ] && [ -s "$STEP0_CONDA_FALLBACK_MAP" ]; then
  record_status "conda_fallback" "started" "$CONDA_FALLBACK_STATUS"
  tail -n +2 "$R_FAILED_FILE" | while IFS=$'\t' read -r group pkg installer reason log_file; do
    [ -n "${pkg:-}" ] || continue
    spec="$(load_conda_fallback_spec "$pkg")"
    if [ -z "$spec" ]; then
      printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$pkg" "skipped_no_spec" "" "" >> "$CONDA_FALLBACK_STATUS"
      continue
    fi
    pkg_log="$LOG_DIR/${STEP0_ENV_NAME}_conda_fallback_${pkg}_${STAMP}.log"
    printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$pkg" "started" "$spec" "$pkg_log" >> "$CONDA_FALLBACK_STATUS"
    if step0_run_conda install -y -p "$STEP0_ENV_PREFIX" --override-channels "${STEP0_CHANNEL_ARGS[@]}" "$spec" > "$pkg_log" 2>&1; then
      printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$pkg" "finished" "$spec" "$pkg_log" >> "$CONDA_FALLBACK_STATUS"
    else
      printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$pkg" "failed" "$spec" "$pkg_log" >> "$CONDA_FALLBACK_STATUS"
    fi
  done
  record_status "conda_fallback" "finished" "$CONDA_FALLBACK_STATUS"
else
  record_status "conda_fallback" "skipped" "$R_FAILED_FILE"
fi

python_import_name() {
  case "$1" in
    opencv) echo "cv2" ;;
    pyside2) echo "PySide2" ;;
    *) echo "$1" ;;
  esac
}

printf "time\tpackage\tstatus\tspec\tlog_file\n" > "$PYTHON_CONDA_STATUS"
record_status "python_conda" "started" "$PYTHON_CONDA_STATUS"
for spec in $STEP0_DEFERRED_PYTHON_PACKAGES; do
  pkg_log="$LOG_DIR/${STEP0_ENV_NAME}_python_conda_${spec}_${STAMP}.log"
  module="$(python_import_name "$spec")"
  printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$spec" "started" "$spec" "$pkg_log" >> "$PYTHON_CONDA_STATUS"
  if step0_run_conda install -y -p "$STEP0_ENV_PREFIX" --override-channels "${STEP0_CHANNEL_ARGS[@]}" "$spec" > "$pkg_log" 2>&1 && \
    ST_STEP0_PY_MODULE="$module" "$STEP0_ENV_PREFIX/bin/python" - <<'PY' >/dev/null 2>&1
import importlib
import os
importlib.import_module(os.environ["ST_STEP0_PY_MODULE"])
PY
  then
    printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$spec" "finished" "$spec" "$pkg_log" >> "$PYTHON_CONDA_STATUS"
  else
    printf "%s\t%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$spec" "failed" "$spec" "$pkg_log" >> "$PYTHON_CONDA_STATUS"
  fi
done
record_status "python_conda" "finished" "$PYTHON_CONDA_STATUS"

record_status "validation" "started" "scripts/setup/validate_step0.R"
export ST_STEP0_VALIDATE_R_PACKAGES="$STEP0_VALIDATE_R_PACKAGES"
export ST_STEP0_VALIDATE_PYTHON_MODULES="$STEP0_VALIDATE_PYTHON_MODULES"
if Rscript scripts/setup/validate_step0.R; then
  record_status "validation" "finished" "step0 validation passed"
else
  record_status "validation" "failed" "step0 validation failed"
  record_status "setup" "finished_with_validation_failures" "$LOG_FILE"
  if [ "$STEP0_FAIL_ON_VALIDATION" = "true" ]; then
    exit 1
  fi
  exit 0
fi

record_status "setup" "finished" "$LOG_FILE"
