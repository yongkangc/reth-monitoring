#!/bin/bash

# Reth & Lighthouse Monitoring Script
# This script checks if both clients are running and syncing properly

set -euo pipefail

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Logging
LOG_FILE="${LOG_DIR}/monitor-$(date +%Y%m%d).log"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Initialize issue tracking
ISSUES=()

# Function to send Slack notification
send_alert() {
    local message="$1"
    log "ALERT: $message"
    "${SCRIPT_DIR}/slack-notify.sh" "$message"
}

# Check if Reth process is running
check_reth_process() {
    log "Checking Reth process..."
    if pgrep -x "reth" > /dev/null; then
        log "✓ Reth process is running (PID: $(pgrep -x 'reth'))"
        return 0
    else
        ISSUES+=("Reth process is not running")
        return 1
    fi
}

# Check if Lighthouse process is running
check_lighthouse_process() {
    log "Checking Lighthouse process..."
    if pgrep -f "lighthouse.*bn" > /dev/null; then
        log "✓ Lighthouse process is running (PID: $(pgrep -f 'lighthouse.*bn'))"
        return 0
    else
        ISSUES+=("Lighthouse beacon node is not running")
        return 1
    fi
}

# Check if Reth Engine API port is responding
check_reth_port() {
    log "Checking Reth Engine API port $RETH_ENGINE_PORT..."
    if nc -z localhost "$RETH_ENGINE_PORT" 2>/dev/null; then
        log "✓ Reth Engine API port $RETH_ENGINE_PORT is responding"
        return 0
    else
        ISSUES+=("Reth Engine API port $RETH_ENGINE_PORT is not responding")
        return 1
    fi
}

# Check if Lighthouse HTTP API port is responding
check_lighthouse_port() {
    log "Checking Lighthouse HTTP API port $LIGHTHOUSE_HTTP_PORT..."
    if nc -z localhost "$LIGHTHOUSE_HTTP_PORT" 2>/dev/null; then
        log "✓ Lighthouse HTTP API port $LIGHTHOUSE_HTTP_PORT is responding"
        return 0
    else
        ISSUES+=("Lighthouse HTTP API port $LIGHTHOUSE_HTTP_PORT is not responding")
        return 1
    fi
}

# Check Reth sync status from logs
check_reth_sync_status() {
    log "Checking Reth sync status from logs..."

    if [[ ! -f "$RETH_LOG_FILE" ]]; then
        ISSUES+=("Reth log file not found at $RETH_LOG_FILE")
        return 1
    fi

    # Get last 100 lines and check for recent sync activity
    local recent_logs=$(tail -n 100 "$RETH_LOG_FILE")

    # Check for error patterns
    if echo "$recent_logs" | grep -qi "error\|fatal\|panic\|failed"; then
        local error_count=$(echo "$recent_logs" | grep -ci "error\|fatal\|panic")
        if [[ $error_count -gt 5 ]]; then
            ISSUES+=("Reth has $error_count recent errors in logs")
        fi
    fi

    # Check for sync progress indicators
    if echo "$recent_logs" | grep -qi "syncing\|downloaded\|stage.*progress\|block.*imported"; then
        log "✓ Reth appears to be syncing (recent activity detected)"
        return 0
    else
        # Check if already synced
        if echo "$recent_logs" | grep -qi "synced\|up to date"; then
            log "✓ Reth is fully synced"
            return 0
        else
            ISSUES+=("Reth shows no recent sync activity in logs")
            return 1
        fi
    fi
}

# Check Lighthouse sync status
check_lighthouse_sync_status() {
    log "Checking Lighthouse sync status..."

    if [[ ! -f "$LIGHTHOUSE_LOG_FILE" ]]; then
        ISSUES+=("Lighthouse log file not found at $LIGHTHOUSE_LOG_FILE")
        return 1
    fi

    local recent_logs=$(tail -n 100 "$LIGHTHOUSE_LOG_FILE")

    # Check for error patterns
    if echo "$recent_logs" | grep -qi "error\|crit\|warn.*execution"; then
        local error_count=$(echo "$recent_logs" | grep -ci "error\|crit")
        if [[ $error_count -gt 5 ]]; then
            ISSUES+=("Lighthouse has $error_count recent errors in logs")
        fi
    fi

    # Check for sync indicators
    if echo "$recent_logs" | grep -qi "synced\|syncing.*head"; then
        log "✓ Lighthouse appears to be syncing or synced"
        return 0
    else
        ISSUES+=("Lighthouse shows no recent sync activity in logs")
        return 1
    fi
}

# Main monitoring logic
main() {
    log "=========================================="
    log "Starting Reth & Lighthouse monitoring check"
    log "=========================================="

    # Run all checks
    check_reth_process || true
    check_lighthouse_process || true
    check_reth_port || true
    check_lighthouse_port || true
    check_reth_sync_status || true
    check_lighthouse_sync_status || true

    # Report results
    if [[ ${#ISSUES[@]} -eq 0 ]]; then
        log "✓ All checks passed - Reth and Lighthouse are running normally"
    else
        log "✗ ${#ISSUES[@]} issue(s) detected:"
        for issue in "${ISSUES[@]}"; do
            log "  - $issue"
        done

        # Send consolidated alert to Slack
        local alert_message="🚨 *Reth/Lighthouse Monitoring Alert*\n\n"
        alert_message+="*Issues Detected:*\n"
        for issue in "${ISSUES[@]}"; do
            alert_message+="• $issue\n"
        done
        alert_message+="\n*Host:* $(hostname)\n*Time:* $(date '+%Y-%m-%d %H:%M:%S')"

        send_alert "$alert_message"
    fi

    log "Monitoring check completed"
    log "=========================================="
}

main "$@"
