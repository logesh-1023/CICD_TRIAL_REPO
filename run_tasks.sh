#!/bin/bash

REPO_DIR="$(cd "$(dirname "$0")"; pwd)"
TASK_DIR="$REPO_DIR/tasks"
LOG_DIR="$REPO_DIR/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

cd "$REPO_DIR"
git pull origin main

cd "$TASK_DIR"

# Check for manifest.json
if [ ! -f manifest.json ]; then
  echo "[$TIMESTAMP] manifest.json not found" > "$LOG_DIR/error_$TIMESTAMP.log"
  exit 1
fi

# Parse manifest
ENTRY=$(jq -r '.entrypoint' manifest.json)
ARGS=$(jq -r '.args // empty | join(" ")' manifest.json)

if [ ! -f "$ENTRY" ]; then
  echo "[$TIMESTAMP] Entrypoint '$ENTRY' not found!" > "$LOG_DIR/error_$TIMESTAMP.log"
  exit 1
fi

# Run the script
LOG_FILE="$LOG_DIR/${ENTRY%.py}_$TIMESTAMP.log"
python3 "$ENTRY" $ARGS > "$LOG_FILE" 2>&1

# Send result to Slack (update your webhook below)
SLACK_WEBHOOK="https://hooks.slack.com/services/your/slack/webhook"
curl -X POST -H 'Content-type: application/json'   --data "{"text":"Execution of $ENTRY complete. Log output:
$(tail -n 10 "$LOG_FILE")"}"   "$SLACK_WEBHOOK"
