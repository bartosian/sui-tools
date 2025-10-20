# Quick Setup Guide

## Prerequisites
- Docker and Docker Compose installed
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

# Restart services
./monitor.sh restart
```

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
│   ├── prometheus.yml          # Main Prometheus config
│   └── rules/
│       └── sui_bridge_alerts.yml
├── alertmanager/
│   └── alertmanager.yml        # Main Alertmanager config
└── grafana/
    ├── datasources.yml         # Grafana datasources
    └── dashboards.yml          # Dashboard provisioning
```

### Customization

#### Update Prometheus Targets
Edit `config/prometheus/prometheus.yml`:
- For Linux: Use `localhost:PORT`
- For macOS: Use `host.docker.internal:PORT`
- The current config supports both automatically

#### Update Alert Rules
Edit files in `config/prometheus/rules/`:
- Rules are automatically loaded on startup
- Restart Prometheus after changes: `docker compose restart prometheus`

#### Update Alertmanager Receivers
Edit `config/alertmanager/alertmanager.yml`:
- Configure PagerDuty, Telegram, Discord integrations
- Set up routing rules based on severity
- Restart Alertmanager after changes: `docker compose restart alertmanager`

## Accessing Services

- **Grafana**: http://localhost:3000
  - Default credentials: See `.env` file
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

## Troubleshooting

### Services Not Starting

1. **Check logs**:
   ```bash
   docker compose logs <service_name>
   ```

2. **Verify configuration**:
   ```bash
   # For Prometheus
   docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
   
   # For Alertmanager
   docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
   ```

3. **Check port conflicts**:
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
# Restart the specific service
docker compose restart <service_name>

# Or restart all services
docker compose restart
```

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

# Sui Targets
bridges:
  mainnet:
    target: host.docker.internal:9186
    public_address: host.docker.internal:9187
  testnet:
    target: host.docker.internal:9185
    public_address: host.docker.internal:9188

sui:
  validator: your_validator_name

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

1. Configure your `config.yml` file with actual values
2. Start the services: `./monitor.sh start`
3. Access Grafana and log in
4. Verify Prometheus targets are being scraped
5. Test alert rules by triggering conditions
6. Configure notification channels in Alertmanager
