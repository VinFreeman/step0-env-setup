#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-${PWD}}"
CONFIG="${2:-config/step0_env.yaml}"
STATUS_ONLY=0
DIAGNOSTICS=0
TAIL_LINES=80

shift $(( $# > 0 ? 1 : 0 ))
shift $(( $# > 0 ? 1 : 0 ))

while [ "$#" -gt 0 ]; do
  case "$1" in
    --status-only) STATUS_ONLY=1; shift ;;
    --diagnostics) DIAGNOSTICS=1; shift ;;
    --tail-lines) TAIL_LINES="${2:?missing value for --tail-lines}"; shift 2 ;;
    --tail-lines=*) TAIL_LINES="${1#*=}"; shift ;;
    *) echo "ERROR=unknown_arg:$1" >&2; exit 2 ;;
  esac
done

cd "$ROOT"
source run/step0/step0_env_lib.sh
step0_load_config "$CONFIG"
PID_FILE="logs/setup/setup_${STEP0_ENV_NAME}.pid"

if [ ! -s "$PID_FILE" ]; then
  echo "STATUS=NO_PID"
else
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" 2>/dev/null; then
    echo "STATUS=RUNNING"
    echo "PID=$PID"
  else
    echo "STATUS=NOT_RUNNING"
    echo "PID=$PID"
  fi
fi

LATEST_OUTER="$(ls -1t logs/setup/setup_${STEP0_ENV_NAME}_*.outer.log 2>/dev/null | head -1 || true)"
LATEST_INNER="$(ls -1t logs/setup/setup_${STEP0_ENV_NAME}_*.log 2>/dev/null | grep -v '[.]outer[.]log$' | head -1 || true)"
LATEST_STATUS="$(ls -1t logs/setup/setup_${STEP0_ENV_NAME}_*.status.tsv 2>/dev/null | head -1 || true)"
LATEST_R_STATUS="$(ls -1t logs/setup/${STEP0_ENV_NAME}_r_packages_*.status.tsv 2>/dev/null | head -1 || true)"
LATEST_R_FAILED="$(ls -1t logs/setup/${STEP0_ENV_NAME}_r_packages_*.failed.tsv 2>/dev/null | head -1 || true)"
LATEST_CONDA_FALLBACK="$(ls -1t logs/setup/${STEP0_ENV_NAME}_conda_fallback_*.status.tsv 2>/dev/null | head -1 || true)"
LATEST_PYTHON_CONDA="$(ls -1t logs/setup/${STEP0_ENV_NAME}_python_conda_*.status.tsv 2>/dev/null | head -1 || true)"
LATEST_R_LOG_DIR="$(ls -1dt logs/setup/${STEP0_ENV_NAME}_r_package_logs_* 2>/dev/null | head -1 || true)"

echo "LATEST_OUTER=$LATEST_OUTER"
echo "LATEST_INNER=$LATEST_INNER"
echo "LATEST_STATUS=$LATEST_STATUS"
echo "LATEST_R_STATUS=$LATEST_R_STATUS"
echo "LATEST_R_FAILED=$LATEST_R_FAILED"
echo "LATEST_CONDA_FALLBACK=$LATEST_CONDA_FALLBACK"
echo "LATEST_PYTHON_CONDA=$LATEST_PYTHON_CONDA"
echo "R_PACKAGE_LOG_DIR=$LATEST_R_LOG_DIR"

print_log_meta() {
  local label="$1"
  local path="$2"
  if [ -n "$path" ] && [ -f "$path" ]; then
    local size mtime last_line
    size="$(wc -c < "$path" | tr -d ' ')"
    mtime="$(date -r "$path" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || stat -c '%y' "$path" 2>/dev/null || true)"
    last_line="$(tail -n 1 "$path" | tr '\r' ' ' || true)"
    echo "${label}_SIZE_BYTES=$size"
    echo "${label}_MTIME=$mtime"
    echo "${label}_LAST_LINE=$last_line"
  fi
}

print_log_meta "OUTER_LOG" "$LATEST_OUTER"
print_log_meta "INNER_LOG" "$LATEST_INNER"
print_log_meta "STATUS_FILE" "$LATEST_STATUS"
print_log_meta "R_STATUS_FILE" "$LATEST_R_STATUS"
print_log_meta "R_FAILED_FILE" "$LATEST_R_FAILED"
print_log_meta "CONDA_FALLBACK_FILE" "$LATEST_CONDA_FALLBACK"
print_log_meta "PYTHON_CONDA_FILE" "$LATEST_PYTHON_CONDA"

if [ "$DIAGNOSTICS" -eq 1 ]; then
  echo "---- process diagnostics ----"
  if [ -s "$PID_FILE" ]; then
    ROOT_PID="$(cat "$PID_FILE")"
    echo "PROCESS_ROOT_PID=$ROOT_PID"
    ps -o pid,ppid,etime,stat,pcpu,pmem,rss,vsz,args -p "$ROOT_PID" || true
    echo "---- child processes ----"
    mapfile -t CHILD_PIDS < <(pgrep -P "$ROOT_PID" || true)
    if [ "${#CHILD_PIDS[@]}" -gt 0 ]; then
      for child_pid in "${CHILD_PIDS[@]}"; do
        ps -o pid,ppid,etime,stat,pcpu,pmem,rss,vsz,args -p "$child_pid" || true
      done
    fi
  fi
  echo "PROCESS_CONDA_USER=$(pgrep -afu "$USER" 'conda|mamba|micromamba' || true)"
fi

if [ "$STATUS_ONLY" -eq 1 ]; then
  exit 0
fi

for pair in \
  "setup status tail:$LATEST_STATUS" \
  "R package status tail:$LATEST_R_STATUS" \
  "conda fallback status tail:$LATEST_CONDA_FALLBACK" \
  "Python conda status tail:$LATEST_PYTHON_CONDA" \
  "outer log tail:$LATEST_OUTER" \
  "inner log tail:$LATEST_INNER"; do
  label="${pair%%:*}"
  path="${pair#*:}"
  if [ -n "$path" ] && [ -f "$path" ]; then
    echo "---- $label ----"
    tail -n "$TAIL_LINES" "$path"
  fi
done

if [ -n "$LATEST_R_FAILED" ] && [ -f "$LATEST_R_FAILED" ]; then
  echo "---- R package failed list ----"
  cat "$LATEST_R_FAILED"
fi

if [ -n "$LATEST_R_LOG_DIR" ] && [ -d "$LATEST_R_LOG_DIR" ]; then
  echo "---- R package log files ----"
  find "$LATEST_R_LOG_DIR" -maxdepth 1 -type f -name '*.log' -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' | sort | tail -n 40 || true
fi
