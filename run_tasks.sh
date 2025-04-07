#!/bin/bash

# --- Config ---
REPO_DIR="/home/ec2-user/CICD_TRIAL"
TASK_DIR="$REPO_DIR/tasks"
LOG_DIR="$REPO_DIR/logs"
TODAY=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/model_$TODAY.log"
SLACK_WEBHOOK="https://hooks.slack.com/services/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" 

# --- Setup ---
mkdir -p "$LOG_DIR"
cd "$REPO_DIR"

# --- Git Fetch & Detect Changes ---
echo "🔄 Checking for changes in GitHub..." >> "$LOG_FILE"
git fetch origin main >> "$LOG_FILE" 2>&1
CHANGED_FILES=$(git diff --name-only HEAD origin/main)

if [ -z "$CHANGED_FILES" ]; then
    echo "✅ No changes detected at $(date)." >> "$LOG_FILE"
    exit 0
fi

# --- Pull Latest ---
echo -e "\n⬇️ Pulling latest changes..." >> "$LOG_FILE"
git pull origin main >> "$LOG_FILE" 2>&1

# --- Determine main file to run ---
MAIN_FILE="model.py"
if [[ -f "$TASK_DIR/manifest.json" ]]; then
    DYNAMIC_MAIN=$(jq -r '.main' "$TASK_DIR/manifest.json")
    if [[ -n "$DYNAMIC_MAIN" && -f "$TASK_DIR/$DYNAMIC_MAIN" ]]; then
        MAIN_FILE="$DYNAMIC_MAIN"
    fi
fi
MAIN_FILE_PATH="$TASK_DIR/$MAIN_FILE"

# --- Run Main File ---
echo -e "\n▶️ Change detected at $(date). Running $MAIN_FILE...\n" >> "$LOG_FILE"
python3 "$MAIN_FILE_PATH" >> "$LOG_FILE" 2>&1

# --- Check for Errors ---
STATUS="✅ Success"
if grep -i "error\|exception" "$LOG_FILE"; then
    STATUS="⚠️ Error Detected"
fi

# --- Prepare Message for Slack ---
CHANGED_LIST=$(echo "$CHANGED_FILES" | sed 's/^/- /' | paste -sd '\\n')
LAST_OUTPUT=$(tail -n 20 "$LOG_FILE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"[$STATUS] Task *$MAIN_FILE* executed on EC2.\n📦 *Files Changed:*\n$CHANGED_LIST\n\n📄 *Output:*\n\`\`\`$LAST_OUTPUT\`\`\`\"}" \
  $SLACK_WEBHOOK
