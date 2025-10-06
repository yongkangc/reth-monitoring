#!/bin/bash

# Slack Notification Script
# Sends formatted messages to Slack webhook

set -euo pipefail

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Check if webhook URL is configured
if [[ -z "${SLACK_WEBHOOK_URL:-}" ]] || [[ "$SLACK_WEBHOOK_URL" == "YOUR_SLACK_WEBHOOK_URL_HERE" ]]; then
    echo "Error: SLACK_WEBHOOK_URL not configured in $CONFIG_FILE"
    exit 1
fi

# Get message from argument
MESSAGE="${1:-No message provided}"

# Create JSON payload
PAYLOAD=$(cat <<EOF
{
    "text": "$MESSAGE"
}
EOF
)

# Send to Slack
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK_URL")

if [[ "$response" == "200" ]]; then
    echo "✓ Notification sent to Slack successfully"
    exit 0
else
    echo "✗ Failed to send notification to Slack (HTTP $response)"
    exit 1
fi
