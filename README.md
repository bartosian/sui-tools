# 🚀 **Sui Tools**

<img src="./assets/sui_header.png" alt="Sui Tools Header"/>

This repository provides a comprehensive **end-to-end monitoring solution** for **Sui services** using **Grafana**, **Prometheus**, and **Alertmanager**. It includes pre-configured dashboards, alert rules, and notification integrations designed for monitoring various Sui ecosystem services.

### **Supported Sui Services**

Currently supported services:
- **Sui Bridge** - Cross-chain bridge monitoring (Mainnet & Testnet)

*Additional Sui services will be added in future releases*

---

## 📦 **Quick Start**

### **1. Clone and Setup**

```bash
git clone https://github.com/sui-network/sui-tools.git
cd sui-tools
cp config.yml.template config.yml
```

> 📋 **For detailed setup instructions, see [SETUP.md](SETUP.md)**

### **2. Configure Services**

Edit the `config.yml` file with your specific configuration:

```yaml
# Grafana Configuration
grafana:
  admin_user: admin
  admin_password: your_secure_password
  port: 3000

# Prometheus Configuration
prometheus:
  port: 9090
  target: localhost:9090

# Alertmanager Configuration
alertmanager:
  port: 9093
  target: localhost:9093
  default_webhook_port: 3001

# Sui Bridge Configuration (Optional - only configure services you want to monitor)
bridges:
  - alias: "Production Mainnet"
    target: your-mainnet-target:9186
    public_address: your-mainnet-public-address
    alerts:
      # Common alerts (any bridge)
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
      metrics_public_key_availability: true
      # ... configure alerts per bridge

# Sui Validator Configuration
sui:
  validator: your_validator_name

# Notification Services (Optional)
pagerduty:
  integration_key: your_pagerduty_key

telegram:
  bot_token: your_telegram_bot_token
  chat_id: your_chat_id

discord:
  webhook_url: your_discord_webhook_url
```

> **💡 Dynamic Configuration**: The system automatically detects configured bridges and creates monitoring for each one. You can add any number of bridges with custom aliases. If no bridges are configured, bridge monitoring will be automatically skipped.

### **3. Deploy Services**

**Using the management script (recommended):**
```bash
./monitor.sh start
```

**Manual deployment:**

**For Linux (recommended):**
```bash
docker compose up -d
```

**For macOS:**
```bash
docker compose -f docker-compose.macos.yml up -d
```

### **4. Access Services**

- **Grafana Dashboard**: [http://localhost:3000](http://localhost:3000)
- **Prometheus**: [http://localhost:9090](http://localhost:9090)
- **Alertmanager**: [http://localhost:9093](http://localhost:9093)

---

## 🏗️ **Architecture & Structure**

### **Repository Structure**

```
sui-tools/
├── README.md                        # Project documentation
├── SETUP.md                         # Quick setup guide
├── config.yml                       # Main configuration file (user-editable)
├── config.yml.template              # Configuration template
├── assets/                          # Project assets
│   ├── sui_bridge.png
│   └── sui_header.png
├── config/                          # Static configuration templates
│   ├── alertmanager/
│   │   ├── alertmanager.yml         # Static template (for reference)
│   │   └── generated_alertmanager.yml  # Auto-generated (used by container)
│   ├── blackbox/
│   │   ├── blackbox.yml
│   │   └── entrypoint.sh
│   ├── grafana/
│   │   ├── dashboards/
│   │   │   ├── dashboards.yml
│   │   │   └── sui_bridge.json
│   │   ├── datasources/
│   │   │   └── datasources.yml
│   │   └── entrypoint.sh
│   └── prometheus/
│       ├── entrypoint.sh
│       ├── generated_prometheus.yml    # Auto-generated (used by container)
│       └── rules/
│           └── sui_bridge_*_alerts.yml # Auto-generated per bridge
├── scripts/                          # Configuration processing
│   └── parse_config.py               # Python parser (generates all configs)
├── generated_configs/                # Auto-generated configs (runtime)
│   ├── prometheus.yml                # Generated Prometheus config
│   ├── alertmanager.yml              # Generated Alertmanager config
│   ├── bridges.json                  # Bridge metadata JSON
│   └── alert_rules/                  # Generated alert rules per bridge
│       ├── sui_bridge_0_*_alerts.yml
│       └── sui_bridge_1_*_alerts.yml
├── data/                            # Persistent data storage
│   ├── alertmanager/
│   ├── grafana/
│   └── prometheus/
├── docker-compose.macos.yml         # macOS configuration
├── docker-compose.yml               # Linux configuration
└── monitor.sh                       # Management script
```

---

## 📊 **Monitoring Features**

### **Conditional Service Deployment**

The monitoring stack automatically adapts based on your configuration:

- **Dynamic Bridge Detection**: Automatically detects and monitors any number of configured bridges
- **Custom Bridge Aliases**: Use human-readable names instead of hardcoded "mainnet"/"testnet"
- **Dashboard Provisioning**: Service-specific dashboards are only loaded when bridges are configured
- **Alert Rules**: Only active for configured services
- **Resource Optimization**: Unused monitoring components are automatically skipped
- **Python-based Configuration**: Dynamic Prometheus config generation with proper validation

### **Pre-configured Dashboards**

- **Sui Bridge Dashboard**: Comprehensive monitoring of Sui Bridge Node performance

### **Alert Rules**

The system includes comprehensive alert rules for configured services. Alerts are **opt-in** - you must explicitly enable each alert type in your `config.yml` for each bridge.

**Sui Bridge Alerts** (12 alert types available per bridge):

**Common Alerts** (recommended for all bridges):
1. **Uptime** - Detects unexpected node restarts or failures
2. **Metrics Public Key Availability** - Monitors metrics endpoint accessibility  
3. **Ingress Access** - Monitors public bridge endpoint availability
4. **Voting Power** - Critical validator voting rights issues

**Client-Disabled Alerts** (for bridge client node issues):
5. **Bridge Request Errors** - Transaction digest handling failures
6. **High ETH RPC Latency** - ETH RPC query performance issues
7. **High Cache Misses** - Inefficient cache utilization
8. **SUI RPC Errors** - SUI RPC query failures

**Client-Enabled Alerts** (for bridge client synchronization):
9. **Stale SUI Sync** - SUI checkpoint synchronization stalled
10. **Stale ETH Sync** - ETH block synchronization stalled
11. **Stale ETH Finalization** - ETH finalization not progressing
12. **Low Gas Balance** - Bridge client gas balance below threshold (10 SUI)

**Alert Configuration**: Each bridge can have its own alert configuration. Only explicitly enabled alerts will be generated and monitored.

*Additional alert rules will be added as more Sui services are supported*

### **Notification Channels**

All notification channels are **automatically configured** based on credentials provided in `config.yml`:

- **PagerDuty**: Critical alerts only (severity: critical) with automatic escalation
- **Telegram**: Both critical and warning alerts with HTML formatting
- **Discord**: Both critical and warning alerts with webhook integration
- **Webhook**: Fallback for all alerts to custom endpoint

**Configuration is automatic**: Simply add your integration keys/tokens to `config.yml` and the system will generate the appropriate Alertmanager configuration. Alerts are routed based on severity:
- **Critical alerts** → PagerDuty + Telegram + Discord + Webhook
- **Warning alerts** → Telegram + Discord + Webhook

### **Configuration Processing**

The system uses a **Python-based configuration parser** (`scripts/parse_config.py`) that automatically generates all service configurations from your `config.yml`:

**Generated Configurations:**
- **Prometheus config** (`generated_configs/prometheus.yml`) - Dynamic scrape targets for all bridges
- **Alert rules** (`generated_configs/alert_rules/*.yml`) - Bridge-specific alert rules based on enabled alerts
- **Alertmanager config** (`generated_configs/alertmanager.yml`) - Notification receivers based on configured integrations
- **Bridge metadata** (`generated_configs/bridges.json`) - Bridge configuration for Grafana dashboards

**Features:**
- **Validates YAML configuration** with comprehensive error handling
- **Supports custom bridge aliases** instead of hardcoded network names
- **Opt-in alert configuration** - only enabled alerts are generated
- **Conditional notification setup** - only configured services are included
- **Exports environment variables** for Docker Compose integration

**Requirements:**
- Python 3.6+ with PyYAML (`pip3 install PyYAML`)
- The parser runs on the host machine during startup/restart

**How it works:**
1. You edit `config.yml` with your settings
2. Run `./monitor.sh start` or `./monitor.sh restart`
3. Parser generates all configs in `generated_configs/`
4. Configs are copied to respective service directories
5. Services start/restart with updated configurations

---

### **Configuration Options**

The `config.yml` file supports the following configuration sections:

| Section | Option | Description | Required |
|---------|--------|-------------|----------|
| **grafana** | `admin_user` | Grafana admin username | ✅ |
| | `admin_password` | Grafana admin password | ✅ |
| | `port` | Grafana web interface port | ❌ (default: 3000) |
| **prometheus** | `port` | Prometheus port | ❌ (default: 9090) |
| | `target` | Prometheus target | ❌ (default: localhost:9090) |
| **alertmanager** | `port` | Alertmanager port | ❌ (default: 9093) |
| | `target` | Alertmanager target | ❌ (default: localhost:9093) |
| | `default_webhook_port` | Default webhook port | ❌ (default: 3001) |
| **bridges** | `alias` | Human-readable bridge name | ❌* |
| | `target` | Bridge target endpoint (IP:port) | ❌* |
| | `public_address` | Bridge public HTTP address | ❌ |
| **sui** | `validator` | Validator name for alerts | ❌ |
| **pagerduty** | `integration_key` | PagerDuty integration key | ❌ |
| **telegram** | `bot_token` | Telegram bot token | ❌ |
| | `chat_id` | Telegram chat ID | ❌ |
| **discord** | `webhook_url` | Discord webhook URL | ❌ |

*Required only if you want to monitor Sui Bridge services. You can configure any number of bridges with custom aliases. If no bridges are configured, bridge monitoring will be skipped.

### **Service Configuration**

#### **Grafana**
- **Version**: 10.2.0 (latest stable)
- **Port**: 3000 (configurable)
- **Database**: SQLite (configurable to PostgreSQL/MySQL)
- **Plugins**: Support for GitHub plugin installation
- **Provisioning**: Automatic datasource and dashboard provisioning

#### **Prometheus**
- **Version**: v2.47.0 (latest stable)
- **Retention**: 15 days / 10GB (configurable)
- **Scrape Interval**: 15 seconds
- **Admin API**: Enabled for configuration management

#### **Alertmanager**
- **Version**: v0.26.0 (latest stable)
- **Routing**: Intelligent alert routing based on severity
- **Grouping**: Alerts grouped by service and environment
- **Inhibition**: Prevents alert spam with inhibition rules

---

## 🔧 **Advanced Usage**

### **Custom Dashboards**

Add custom dashboards by placing JSON files in `grafana/dashboards/`. The system will automatically provision them.

### **Additional Alert Rules**

Add new alert rules by creating YAML files in `prometheus/rules/`. The system will automatically load them.

### **Plugin Management**

Install Grafana plugins using the `GF_GITHUB_PLUGINS` environment variable:

```bash
GF_GITHUB_PLUGINS="https://github.com/grafana/grafana-clock-panel/releases/download/v1.3.0/grafana-clock-panel-1.3.0.zip"
```

### **Data Backup**

Create backups using the management script:

```bash
# Create backup
./monitor.sh backup

# Restore from backup
./monitor.sh restore backup-file.tar.gz
```

Or manually:
```bash
tar -czf sui-monitoring-backup.tar.gz data/
```

---

## 🚨 **Troubleshooting**

> 📋 **For detailed troubleshooting steps, see [SETUP.md](SETUP.md)**

### **Service Health Checks**

Check service status:
```bash
docker compose ps
```

View service logs:
```bash
docker compose logs grafana
docker compose logs prometheus
docker compose logs alertmanager
```

### **Configuration Validation**

Validate Prometheus configuration:
```bash
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

Validate Alertmanager configuration:
```bash
docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
```

### **Common Issues**

1. **Permission Errors**: Ensure the `data/` directory has proper permissions
2. **Port Conflicts**: Check if ports 3000, 9090, 9093 are available
3. **Configuration Errors**: Validate environment variables and template files
4. **Network Issues**: Verify target endpoints are accessible
5. **Python Parser Issues**: 
   - Ensure Python 3.6+ is installed: `python3 --version`
   - Install PyYAML: `pip3 install PyYAML` (or `pip3 install PyYAML --break-system-packages` on macOS)
   - Check parser output: `python3 scripts/parse_config.py config.yml generated_configs/prometheus.yml`
6. **Bridge Configuration**: Verify bridge aliases are unique and targets are accessible

### **Management Script**

The `monitor.sh` script provides comprehensive management capabilities:

```bash
# Start all services
./monitor.sh start

# Stop all services  
./monitor.sh stop

# Restart all services
./monitor.sh restart

# Check service status
./monitor.sh status

# View service logs
./monitor.sh logs [service_name]

# Create backup
./monitor.sh backup

# Restore from backup
./monitor.sh restore backup-file.tar.gz

# Clean up old data
./monitor.sh clean
```

**Features:**
- **Automatic configuration parsing** using Python parser
- **Dynamic bridge detection** and monitoring setup
- **Service health monitoring** and status reporting
- **Backup and restore** functionality
- **Log aggregation** across all services

---

### **Updating Services**

To update to newer versions, modify the image tags in `docker-compose.yml` and restart:

```bash
docker compose pull
docker compose up -d
```

### **Configuration Changes**

After modifying `config.yml`:

```bash
# Use the management script (recommended - regenerates all configs)
./monitor.sh restart

# Or manually
python3 scripts/parse_config.py config.yml generated_configs/prometheus.yml generated_configs/alert_rules
# Then copy generated configs
cp generated_configs/*.yml config/*/
docker compose down && docker compose up -d
```

**Important**: The `restart` command in `monitor.sh` now:
1. Regenerates all configurations from `config.yml`
2. Stops all containers
3. Starts containers with fresh configurations

This ensures all configuration changes (bridges, alerts, notifications) are properly applied.

### **Data Cleanup**

Clean up old Prometheus data:
```bash
docker compose exec prometheus promtool tsdb clean --retention.time=7d /prometheus
```

---

## 🤝 **Contributing**

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### **Development Setup**

For development, you can run services individually:

```bash
# Start only Prometheus
docker compose up prometheus

# Start with custom configuration
docker compose -f docker-compose.yml -f docker-compose.override.yml up
```

---

## 📝 **License**

This repository is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---

## 🆘 **Support**

For issues and questions:

- **GitHub Issues**: [Create an issue](https://github.com/sui-network/sui-tools/issues)
- **Documentation**: Check this README and inline comments
- **Community**: Join the Sui community for support

---

**Made with ❤️ for the Sui ecosystem**