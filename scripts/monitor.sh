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
CRITICAL_ISSUES=()

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
        CRITICAL_ISSUES+=("Reth process is not running")
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
        CRITICAL_ISSUES+=("Lighthouse beacon node is not running")
        return 1
    fi
}

# Check if Reth Engine API port is responding
check_reth_port() {
    log "Checking Reth Engine API port $RETH_ENGINE_PORT..."
    if timeout 10 nc -z localhost "$RETH_ENGINE_PORT" 2>/dev/null; then
        log "✓ Reth Engine API port $RETH_ENGINE_PORT is responding"
        return 0
    else
        CRITICAL_ISSUES+=("Reth Engine API port $RETH_ENGINE_PORT is not responding")
        return 1
    fi
}

# Check if Lighthouse P2P port is responding
check_lighthouse_port() {
    log "Checking Lighthouse P2P port $LIGHTHOUSE_P2P_PORT..."
    if timeout 10 nc -z localhost "$LIGHTHOUSE_P2P_PORT" 2>/dev/null; then
        log "✓ Lighthouse P2P port $LIGHTHOUSE_P2P_PORT is responding"
        return 0
    else
        CRITICAL_ISSUES+=("Lighthouse P2P port $LIGHTHOUSE_P2P_PORT is not responding")
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
    if echo "$recent_logs" | grep -qi "executed block\|received block from consensus\|forkchoiceupdated\|stage=execution\|syncing\|downloaded\|stage.*progress\|block.*imported"; then
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

    # Check for critical error patterns (excluding normal warnings like FutureSlot)
    local critical_errors=$(echo "$recent_logs" | grep -i "crit\|fatal" | grep -v "FutureSlot" || true)
    if [[ -n "$critical_errors" ]]; then
        local error_count=$(echo "$critical_errors" | wc -l)
        if [[ $error_count -gt 3 ]]; then
            ISSUES+=("Lighthouse has $error_count critical errors in logs")
        fi
    fi

    # Check for sync indicators
    if echo "$recent_logs" | grep -qi "synced\|syncing.*head\|running beacon chain\|peer transitioned\|received status"; then
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
    local total_issues=$((${#ISSUES[@]} + ${#CRITICAL_ISSUES[@]}))

    if [[ $total_issues -eq 0 ]]; then
        log "✓ All checks passed - Reth and Lighthouse are running normally"
    else
        # Log all issues
        if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
            log "✗ ${#CRITICAL_ISSUES[@]} critical issue(s) detected:"
            for issue in "${CRITICAL_ISSUES[@]}"; do
                log "  - $issue"
            done
        fi

        if [[ ${#ISSUES[@]} -gt 0 ]]; then
            log "⚠ ${#ISSUES[@]} informational issue(s) detected:"
            for issue in "${ISSUES[@]}"; do
                log "  - $issue"
            done
        fi

        # Only send Slack alert for critical issues (process/port failures)
        if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
            local alert_message="🚨 *Reth/Lighthouse Monitoring Alert*\n\n"
            alert_message+="*Critical Issues Detected:*\n"
            for issue in "${CRITICAL_ISSUES[@]}"; do
                alert_message+="• $issue\n"
            done
            alert_message+="\n*Host:* $(hostname)\n*Time:* $(date '+%Y-%m-%d %H:%M:%S')"

            send_alert "$alert_message"
        fi
    fi

    log "Monitoring check completed"
    log "=========================================="
}

main "$@"
