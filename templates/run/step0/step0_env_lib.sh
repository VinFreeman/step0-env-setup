#!/usr/bin/env bash

step0_read_yaml_scalar() {
  local key="$1"
  local config="${2:-config/step0_env.yaml}"
  awk -F ': *' -v key="$key" '$1 == key { sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); print $2; exit }' "$config"
}

step0_read_yaml_list() {
  local key="$1"
  local config="${2:-config/step0_env.yaml}"
  awk -v key="$key" '
    $0 ~ "^" key ":" { in_list=1; next }
    in_list && /^[^[:space:]-]/ { exit }
    in_list && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print }
  ' "$config"
}

step0_load_config() {
  local config="${1:-config/step0_env.yaml}"
  STEP0_CONFIG="$config"
  STEP0_REMOTE_ALIAS="$(step0_read_yaml_scalar remote_alias "$config")"
  STEP0_REMOTE_ROOT="$(step0_read_yaml_scalar remote_root "$config")"
  STEP0_ENV_NAME="$(step0_read_yaml_scalar env_name "$config")"
  STEP0_ENV_PREFIX="$(step0_read_yaml_scalar env_prefix "$config")"
  STEP0_ALLOWED_PREFIX_ROOT="$(step0_read_yaml_scalar allowed_prefix_root "$config")"
  STEP0_CONDA_DIR="$(step0_read_yaml_scalar conda_dir "$config")"
  STEP0_BOOTSTRAP_YAML="$(step0_read_yaml_scalar bootstrap_yaml "$config")"
  STEP0_R_PACKAGE_PLAN="$(step0_read_yaml_scalar r_package_plan "$config")"
  STEP0_CONDA_FALLBACK_MAP="$(step0_read_yaml_scalar conda_fallback_map "$config")"
  STEP0_INSTALL_NCPUS="$(step0_read_yaml_scalar install_ncpus "$config")"
  STEP0_MAX_DEPENDENCY_DEPTH="$(step0_read_yaml_scalar max_dependency_depth "$config")"
  STEP0_FORCE_RECREATE="$(step0_read_yaml_scalar force_recreate "$config")"
  STEP0_FAIL_ON_VALIDATION="$(step0_read_yaml_scalar fail_on_validation "$config")"
  STEP0_CRAN_MIRROR="$(step0_read_yaml_scalar cran_mirror "$config")"
  STEP0_BIOC_MIRROR="$(step0_read_yaml_scalar bioc_mirror "$config")"
  STEP0_CONDA_CHANNELS="$(step0_read_yaml_list conda_channels "$config" | tr '\n' ' ')"
  STEP0_DEFERRED_PYTHON_PACKAGES="$(step0_read_yaml_list deferred_python_packages "$config" | tr '\n' ' ')"
  STEP0_VALIDATE_R_PACKAGES="$(step0_read_yaml_list validate_r_packages "$config" | paste -sd, -)"
  STEP0_VALIDATE_PYTHON_MODULES="$(step0_read_yaml_list validate_python_modules "$config" | paste -sd, -)"
}

step0_record_status() {
  local status_file="$1"
  local stage="$2"
  local status="$3"
  local details="${4:-}"
  if [ ! -f "$status_file" ]; then
    printf "time\tstage\tstatus\tdetails\n" > "$status_file"
  fi
  printf "%s\t%s\t%s\t%s\n" "$(date '+%F %T')" "$stage" "$status" "$details" >> "$status_file"
  printf "[%s] %s %s %s\n" "$(date '+%F %T')" "$stage" "$status" "$details"
}

step0_write_condarc() {
  local condarc="$1"
  local clean_home="$2"
  shift 2
  local channels=("$@")
  mkdir -p "$(dirname "$condarc")" "$clean_home"
  {
    printf "channels:\n"
    for channel in "${channels[@]}"; do
      printf "  - %s\n" "$channel"
    done
    printf "channel_alias: https://conda.anaconda.org\n"
    printf "custom_channels:\n"
    for channel in "${channels[@]}"; do
      printf "  %s: https://conda.anaconda.org\n" "$channel"
    done
    printf "channel_priority: strict\n"
    printf "show_channel_urls: true\n"
    printf "override_channels_enabled: true\n"
  } > "$condarc"
  cp "$condarc" "$clean_home/.condarc"
}

step0_channel_args() {
  local channel
  for channel in $STEP0_CONDA_CHANNELS; do
    printf "%s\n" "-c"
    printf "%s\n" "$channel"
  done
}

step0_run_conda() {
  env \
    HOME="$STEP0_CONDA_CLEAN_HOME" \
    CONDARC="$STEP0_CONDARC" \
    CONDA_SOLVER="classic" \
    CONDA_PKGS_DIRS="$STEP0_CONDA_PKGS_DIRS" \
    "$STEP0_CONDA_DIR/bin/conda" "$@"
}

step0_configure_r_makevars() {
  local makevars="$1"
  mkdir -p "$(dirname "$makevars")"
  cat > "$makevars" <<'MAKEVARS'
CC=/usr/bin/gcc
CXX=/usr/bin/g++
CXX11=/usr/bin/g++
CXX14=/usr/bin/g++
CXX17=/usr/bin/g++
FC=/usr/bin/gfortran
F77=/usr/bin/gfortran
AR=/usr/bin/ar
RANLIB=/usr/bin/ranlib
MAKEVARS
  export R_MAKEVARS_USER="$makevars"
  export AR="/usr/bin/ar"
  export RANLIB="/usr/bin/ranlib"
}

step0_guarded_rm_env_prefix() {
  local target="$1"
  local allowed_root="${STEP0_ALLOWED_PREFIX_ROOT:?STEP0_ALLOWED_PREFIX_ROOT is required}"
  case "$target" in
    "$allowed_root"/*)
      if [ "$target" = "$allowed_root" ]; then
        echo "Refusing to remove allowed root itself: $target" >&2
        return 2
      fi
      rm -rf -- "$target"
      ;;
    *)
      echo "Refusing to remove unexpected env prefix: $target" >&2
      return 2
      ;;
  esac
}
