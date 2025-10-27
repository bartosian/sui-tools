# Quick Setup Guide

## Prerequisites
- Docker and Docker Compose installed
- Python 3.6+ with PyYAML (`pip3 install PyYAML`)
- `config.yml` file configured (copy from `config.yml.template` if needed)

## Quick Start

### Using the Management Script (Recommended)

```bash
# Start all services (auto-detects platform)
./monitor.sh start

# Check service status
./monitor.sh status

# View logs
./monitor.sh logs prometheus
./monitor.sh logs alertmanager
./monitor.sh logs grafana

# Stop services
./monitor.sh stop

# Restart services (regenerates configs automatically)
./monitor.sh restart
```

**Note**: The `restart` command automatically:
1. Regenerates all configurations from `config.yml`
2. Stops all containers
3. Starts containers with fresh configurations

### Manual Deployment

#### For Linux:
```bash
docker compose up -d
```

#### For macOS:
```bash
docker compose -f docker-compose.macos.yml up -d
```

## Configuration Files

### Structure
```
config/
├── prometheus/
│   ├── entrypoint.sh                     # Prometheus startup script
│   ├── generated_prometheus.yml          # Auto-generated (used by container)
│   └── rules/
│       ├── sui_bridge_*_alerts.yml       # Auto-generated per bridge
│       └── sui_validator_*_alerts.yml    # Auto-generated per validator
├── alertmanager/
│   ├── alertmanager.yml                  # Static template (reference only)
│   └── generated_alertmanager.yml        # Auto-generated (used by container)
├── grafana/
│   ├── datasources.yml                   # Grafana datasources
│   ├── dashboards.yml                    # Dashboard provisioning
│   ├── dashboards/
│   │   └── sui_bridge.json               # Bridge monitoring dashboard
│   └── entrypoint.sh                     # Grafana startup script
└── blackbox/
    ├── blackbox.yml                      # Blackbox exporter config
    └── entrypoint.sh                     # Blackbox startup script

scripts/
└── parse_config.py                       # Python configuration parser

generated_configs/                        # Auto-generated at runtime
├── prometheus.yml                        # Generated Prometheus config
├── alertmanager.yml                      # Generated Alertmanager config
├── bridges.json                          # Bridge configuration JSON
├── validators.json                       # Validator configuration JSON
└── alert_rules/                          # Per-service alert rules
    ├── sui_bridge_0_*_alerts.yml         # Per-bridge alerts
    ├── sui_bridge_1_*_alerts.yml
    ├── sui_validator_0_*_alerts.yml      # Per-validator alerts
    └── sui_validator_1_*_alerts.yml
```

### Customization

#### Update Bridge Configuration
Edit `config.yml` to add/modify bridges with per-bridge alert configuration:
```yaml
bridges:
  - alias: "Production Mainnet"
    target: your-mainnet-target:9186
    public_address: your-mainnet-public-address
    alerts:
      # Common alerts (recommended for all bridges)
      uptime: true
      metrics_public_key_availability: true
      ingress_access: true
      voting_power: true
      
      # Client-disabled alerts
      bridge_requests_errors: true
      bridge_high_latency: true
      bridge_high_cache_misses: true
      bridge_rpc_errors: true
      
      # Client-enabled alerts  
      stale_sui_sync: true
      stale_eth_sync: true
      stale_eth_finalization: true
      low_gas_balance: true
  - alias: "Test Network"
    target: your-testnet-target:9185
    public_address: your-testnet-public-address
    alerts:
      uptime: true
      # ... configure alerts per bridge
```

**Important**: 
- Alerts are **opt-in** - only explicitly enabled alerts will be generated
- Each bridge can have different alert configurations
- Missing alerts default to `false` (disabled)

#### Update Validator Configuration
Edit `config.yml` to add/modify validators with per-validator alert configuration:
```yaml
sui:
  validator: your_validator_authority_name  # Required for validator alerts

validators:
  - alias: "Production Validator"
    target: localhost:9184
    alerts:
      # Critical alerts (severity: critical → PagerDuty + Telegram + Discord + Webhook)
      uptime: true                              # Monitor validator uptime (5m window)
      voting_power: true                        # Alert if validator has zero voting power (5m window)
      tx_processing_latency_p95: true           # Critical: P95 transaction latency > 15s (5m window)
      tx_processing_latency_p50: true           # Critical: P50 transaction latency > 5s (5m window)
      proposal_latency: true                    # Critical: Consensus proposal latency > 2s (5m window)
      consensus_block_commit_rate: true         # Critical: Consensus block commit rate < 3 blocks/s (5m window)
      committed_round_rate: true                # Critical: Committed round rate < 3 rounds/s (5m window)
      fullnode_connectivity: true               # Critical: RPC errors indicating connectivity issues (5m window)
      
      # Warning alerts (severity: warning → Telegram + Discord + Webhook, NO PagerDuty)
      reputation_rank: true                     # Alert if validator is consistently in bottom N (30m window)
      tx_processing_latency_p95_10s: true       # Warning: P95 transaction latency > 10s (5m window)
      tx_processing_latency_p95_3s: true        # Warning: P95 transaction latency > 3s (5m window)
  - alias: "Test Validator"
    target: test-validator:9184
    alerts:
      uptime: true
      # ... configure alerts per validator
```

**Important**:
- Alerts are **opt-in** - only explicitly enabled alerts will be generated
- Each validator can have different alert configurations
- Missing alerts default to `false` (disabled)
- Critical alerts trigger PagerDuty, warning alerts do not
- The `sui.validator` field must contain your validator's authority name

#### Update Prometheus Targets
Prometheus targets are automatically generated from `config.yml`. No manual editing required!

#### Update Alert Rules
Alert rules are automatically generated based on enabled alerts in `config.yml`:
- Each bridge gets its own alert rules file
- Each validator gets its own alert rules file
- Only enabled alerts are generated
- Restart services to apply: `./monitor.sh restart`

#### Update Notification Integrations
Configure notification services in `config.yml`:
```yaml
# PagerDuty (critical alerts only)
pagerduty:
  integration_key: "your_pagerduty_integration_key"

# Telegram (all alerts)
telegram:
  bot_token: "your_telegram_bot_token"
  chat_id: "your_chat_id"

# Discord (all alerts)
discord:
  webhook_url: "your_discord_webhook_url"
```

**Automatic Configuration**:
- Alertmanager config is auto-generated based on configured services
- Only services with credentials are included
- Restart to apply changes: `./monitor.sh restart`

## Accessing Services

- **Grafana**: http://localhost:3000
  - Default credentials: See `config.yml` file
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## Troubleshooting

### Services Not Starting

1. **Check Python parser**:
   ```bash
   python3 scripts/parse_config.py config.yml generated_configs/prometheus.yml
   ```

2. **Check logs**:
   ```bash
   ./monitor.sh logs [service_name]
   # or
   docker compose logs <service_name>
   ```

3. **Verify configuration**:
   ```bash
   # For Prometheus
   docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
   
   # For Alertmanager
   docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
   ```

4. **Check port conflicts**:
   ```bash
   lsof -i :3000  # Grafana
   lsof -i :9090  # Prometheus
   lsof -i :9093  # Alertmanager
   ```

### Permission Issues

```bash
# Ensure data directories exist and have proper permissions
mkdir -p data/grafana data/prometheus data/alertmanager
chmod -R 755 data/
```

### Configuration Changes Not Applied

```bash
# Restart all services (REQUIRED - regenerates configs)
./monitor.sh restart
```

**Important**: Always use `./monitor.sh restart` after editing `config.yml`. This command:
1. Parses `config.yml` and validates configuration
2. Generates Prometheus config with your bridge targets
3. Generates Alertmanager config with your notification settings
4. Generates alert rules based on enabled alerts
5. Stops and restarts all containers with new configs

Manual restart (`docker compose restart`) will NOT pick up config changes!

## Data Management

### Backup
```bash
./monitor.sh backup
# or
tar -czf backup-$(date +%Y%m%d).tar.gz data/
```

### Restore
```bash
./monitor.sh restore backup-YYYYMMDD.tar.gz
# or
tar -xzf backup-YYYYMMDD.tar.gz
```

### Clean Up
```bash
# Remove all containers and data
./monitor.sh cleanup

# Or manually
docker compose down -v
rm -rf data/
```

## Platform-Specific Notes

### Linux
- Uses `network_mode: host` for better performance
- Services communicate via localhost
- Direct access to host network interfaces

### macOS
- Uses bridge networking (macOS doesn't support host mode)
- Services communicate via Docker network
- Access host services via `host.docker.internal`

## Configuration

Key configuration in `config.yml`:

```yaml
# Grafana
grafana:
  admin_user: admin
  admin_password: secure_password
  port: 3000

# Prometheus
prometheus:
  port: 9090
  target: localhost:9090

# Alertmanager
alertmanager:
  port: 9093
  target: localhost:9093
  default_webhook_port: 3001

# Sui Targets (Dynamic Bridge Configuration)
bridges:
  - alias: "Production Mainnet"
    target: host.docker.internal:9186
    public_address: host.docker.internal:9187
  - alias: "Test Network"
    target: host.docker.internal:9185
    public_address: host.docker.internal:9188
  - alias: "Development"
    target: localhost:9189
    public_address: http://localhost:9190

sui:
  validator: your_validator_authority_name

validators:
  - alias: "Production Validator"
    target: localhost:9184
    alerts:
      uptime: true
      voting_power: true
      tx_processing_latency_p95: true
      tx_processing_latency_p50: true
      proposal_latency: true
      consensus_block_commit_rate: true
      committed_round_rate: true
      fullnode_connectivity: true
      reputation_rank: true
      tx_processing_latency_p95_10s: true
      tx_processing_latency_p95_3s: true

# Notifications (optional)
pagerduty:
  integration_key: ""

telegram:
  bot_token: ""
  chat_id: ""

discord:
  webhook_url: ""
```

## Health Checks

All services include health checks:
- Prometheus: `http://localhost:9090/-/healthy`
- Alertmanager: `http://localhost:9093/-/healthy`
- Grafana: `http://localhost:3000/api/health`

Check health status:
```bash
docker compose ps
```

## Next Steps

1. **Configure `config.yml`**:
   - Set Grafana credentials
   - Add your bridge targets with custom aliases (if monitoring bridges)
   - Add your validator targets with custom aliases (if monitoring validators)
   - Enable desired alerts per bridge/validator
   - Add notification integrations (PagerDuty, Telegram, Discord)

2. **Start services**: `./monitor.sh start`

3. **Verify setup**:
   - Access Grafana at http://localhost:3000
   - Check Prometheus targets at http://localhost:9090/targets
   - Verify alert rules at http://localhost:9090/alerts
   - Check Alertmanager config at http://localhost:9093

4. **Test notifications**:
   - Trigger a test alert
   - Verify notifications arrive via configured channels

5. **Monitor your services**:
   - View Sui Bridge dashboard in Grafana (if bridges configured)
   - View Sui Validator dashboard in Grafana (if validators configured)
   - Check alert status in Prometheus/Alertmanager
   - Review metrics and performance
