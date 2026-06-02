#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${1:-${PWD}}"
CONFIG="${2:-config/step0_env.yaml}"
cd "$ROOT"
source run/step0/step0_env_lib.sh
step0_load_config "$CONFIG"
mkdir -p logs/setup

STAMP="$(date '+%Y%m%d_%H%M%S')"
PID_FILE="logs/setup/setup_${STEP0_ENV_NAME}.pid"
OUTER_LOG="logs/setup/setup_${STEP0_ENV_NAME}_${STAMP}.outer.log"
INNER_LOG="logs/setup/setup_${STEP0_ENV_NAME}_${STAMP}.log"
STATUS_FILE="logs/setup/setup_${STEP0_ENV_NAME}_${STAMP}.status.tsv"
MANIFEST="logs/setup/setup_${STEP0_ENV_NAME}_${STAMP}.manifest.tsv"

if [ -s "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE")"
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "setup already running: PID=$OLD_PID"
    echo "PID_FILE=$PID_FILE"
    exit 0
  fi
fi

{
  printf "key\tvalue\n"
  printf "started_at\t%s\n" "$(date '+%F %T %Z')"
  printf "root\t%s\n" "$ROOT"
  printf "config\t%s\n" "$CONFIG"
  printf "env_name\t%s\n" "$STEP0_ENV_NAME"
  printf "env_prefix\t%s\n" "$STEP0_ENV_PREFIX"
  printf "outer_log\t%s\n" "$OUTER_LOG"
  printf "inner_log\t%s\n" "$INNER_LOG"
  printf "status_file\t%s\n" "$STATUS_FILE"
} > "$MANIFEST"

SETUP_STAMP="$STAMP" nohup bash run/step0/setup.sh "$ROOT" "$CONFIG" > "$OUTER_LOG" 2>&1 &
PID="$!"
echo "$PID" > "$PID_FILE"

printf "PID=%s\n" "$PID"
printf "PID_FILE=%s\n" "$PID_FILE"
printf "OUTER_LOG=%s\n" "$OUTER_LOG"
printf "INNER_LOG=%s\n" "$INNER_LOG"
printf "STATUS_FILE=%s\n" "$STATUS_FILE"
printf "MANIFEST=%s\n" "$MANIFEST"
