# Reth & Lighthouse Monitoring System

Automated monitoring system that checks Reth execution client and Lighthouse consensus client health, sending Slack alerts when issues are detected.

## What It Monitors

✓ **Process Status**: Checks if Reth and Lighthouse processes are running
✓ **Port Connectivity**: Verifies Engine API (8551) and HTTP API (5052) are responding
✓ **Sync Status**: Analyzes logs to confirm clients are syncing properly
✓ **Error Detection**: Identifies excessive errors in recent logs

## Setup Instructions

### 1. Configure Slack Webhook

1. Go to https://api.slack.com/messaging/webhooks
2. Create a new webhook for your workspace
3. Copy the webhook URL
4. Edit `config.env`:
   ```bash
   nano ~/reth-monitoring/config.env
   ```
5. Replace `YOUR_SLACK_WEBHOOK_URL_HERE` with your actual webhook URL

### 2. Verify Log Paths

Edit `config.env` and confirm these paths match your setup:

```bash
# Reth log location
RETH_LOG_FILE="/home/ubuntu/reth/logs/reth.log"

# Lighthouse log location
LIGHTHOUSE_LOG_FILE="/home/ubuntu/.lighthouse/beacon/logs/beacon.log"
```

If your logs are in different locations, update these paths.

### 3. Make Scripts Executable

```bash
chmod +x ~/reth-monitoring/scripts/*.sh
```

### 4. Test the Monitoring

Run manually to verify it works:

```bash
~/reth-monitoring/scripts/monitor.sh
```

Check the output and verify:
- All checks run successfully
- If issues exist, you receive a Slack notification
- Logs are written to `~/reth-monitoring/logs/`

### 5. Setup Daily Cron Job

Run the setup script:

```bash
~/reth-monitoring/scripts/setup-cron.sh
```

This installs a cron job that runs daily at 9:00 AM.

To customize the schedule, edit your crontab:

```bash
crontab -e
```

## Directory Structure

```
reth-monitoring/
├── config.env              # Configuration file
├── README.md               # This file
├── scripts/
│   ├── monitor.sh         # Main monitoring script
│   ├── slack-notify.sh    # Slack notification helper
│   └── setup-cron.sh      # Cron job installer
└── logs/                   # Monitoring logs (auto-created)
```

## Cron Schedule Examples

```bash
# Daily at 9:00 AM (default)
0 9 * * * /home/ubuntu/reth-monitoring/scripts/monitor.sh

# Every 6 hours
0 */6 * * * /home/ubuntu/reth-monitoring/scripts/monitor.sh

# Every hour
0 * * * * /home/ubuntu/reth-monitoring/scripts/monitor.sh

# Twice daily (9 AM and 9 PM)
0 9,21 * * * /home/ubuntu/reth-monitoring/scripts/monitor.sh
```

## Manual Commands

```bash
# Run monitoring check manually
~/reth-monitoring/scripts/monitor.sh

# Test Slack notification
~/reth-monitoring/scripts/slack-notify.sh "Test message"

# View monitoring logs
tail -f ~/reth-monitoring/logs/monitor-$(date +%Y%m%d).log

# View current cron jobs
crontab -l
```

## Troubleshooting

### No Slack notifications received

1. Verify webhook URL in `config.env`
2. Test notification: `~/reth-monitoring/scripts/slack-notify.sh "Test"`
3. Check for curl errors in monitoring logs

### Log file not found errors

1. Verify log paths in `config.env` match your actual setup
2. Check Reth logs location: `ls -la ~/reth/logs/` or wherever Reth logs are
3. Check Lighthouse logs: `ls -la ~/.lighthouse/beacon/logs/`

### Port checks failing

Ensure clients are running with correct ports:
- Reth Engine API: 8551 (default)
- Lighthouse HTTP API: 5052 (default)

### Cron job not running

1. Verify installation: `crontab -l`
2. Check cron logs: `grep CRON /var/log/syslog`
3. Ensure script has execute permissions: `chmod +x ~/reth-monitoring/scripts/monitor.sh`

## Alert Examples

When issues are detected, you'll receive Slack alerts like:

```
🚨 Reth/Lighthouse Monitoring Alert

Issues Detected:
• Reth shows no recent sync activity in logs
• Lighthouse has 8 recent errors in logs

Host: your-server
Time: 2025-10-06 09:00:15
```
