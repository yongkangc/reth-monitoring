#!/bin/bash

# Cron Job Setup Script for Reth/Lighthouse Monitoring

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${SCRIPT_DIR}/monitor.sh"

# Verify monitor script exists
if [[ ! -f "$MONITOR_SCRIPT" ]]; then
    echo "Error: Monitor script not found at $MONITOR_SCRIPT"
    exit 1
fi

# Make sure it's executable
chmod +x "$MONITOR_SCRIPT"

# Define cron job (daily at 9:00 AM)
CRON_JOB="0 9 * * * $MONITOR_SCRIPT"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" > /dev/null; then
    echo "⚠️  Cron job already exists for this monitoring script"
    echo ""
    echo "Current crontab entries for this script:"
    crontab -l | grep -F "$MONITOR_SCRIPT"
    echo ""
    read -p "Do you want to remove and reinstall? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi

    # Remove existing entry
    crontab -l | grep -v -F "$MONITOR_SCRIPT" | crontab -
    echo "✓ Removed existing cron job"
fi

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "✓ Cron job installed successfully!"
echo ""
echo "Schedule: Daily at 9:00 AM"
echo "Command:  $MONITOR_SCRIPT"
echo ""
echo "To verify installation:"
echo "  crontab -l"
echo ""
echo "To customize schedule, edit crontab:"
echo "  crontab -e"
echo ""
echo "Common schedules:"
echo "  0 9 * * *       - Daily at 9:00 AM (current)"
echo "  0 */6 * * *     - Every 6 hours"
echo "  0 * * * *       - Every hour"
echo "  0 9,21 * * *    - Twice daily (9 AM & 9 PM)"
