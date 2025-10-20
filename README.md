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
  mainnet:
    target: your-mainnet-target:9186
    public_address: your-mainnet-public-address
  testnet:
    target: your-testnet-target:9185
    public_address: your-testnet-public-address

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

> **💡 Conditional Deployment**: Only services with configured targets will be monitored. If you don't set bridge targets, the Sui Bridge monitoring will be automatically skipped.

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
├── README.md                       # Project documentation
├── SETUP.md                        # Quick setup guide
├── assets/                         # Project assets
│   ├── sui_bridge.png
│   └── sui_header.png
├── config/                         # Configuration files
│   ├── alertmanager/
│   │   ├── alertmanager.yml
│   │   └── entrypoint.sh
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
│       └── rules/
│           └── sui_bridge_alerts.yml
├── data/                           # Persistent data storage
│   ├── alertmanager/
│   ├── grafana/
│   └── prometheus/
├── docker-compose.macos.yml        # macOS configuration
├── docker-compose.yml              # Linux configuration
└── monitor.sh                      # Management script
```

---

## 📊 **Monitoring Features**

### **Conditional Service Deployment**

The monitoring stack automatically adapts based on your configuration:

- **Sui Bridge Monitoring**: Only deployed if `SUI_BRIDGE_MAINNET_TARGET` or `SUI_BRIDGE_TESTNET_TARGET` are configured
- **Dashboard Provisioning**: Service-specific dashboards are only loaded when corresponding targets are configured
- **Alert Rules**: Only active for configured services
- **Resource Optimization**: Unused monitoring components are automatically skipped

### **Pre-configured Dashboards**

- **Sui Bridge Dashboard**: Comprehensive monitoring of Sui Bridge Node performance

### **Alert Rules**

The system includes comprehensive alert rules for configured services:

**Sui Bridge Alerts** (10 rules - only active when bridge targets are configured):

1. **Node Restarted Alert** - Detects unexpected restarts
2. **ETH Watcher Unrecognized Events** - Monitors ETH watcher issues
3. **SUI Watcher Unrecognized Events** - Monitors SUI watcher issues
4. **Zero Voting Rights Alert** - Critical validator authority issues
5. **Error Requests Alert** - Transaction digest handling errors
6. **SUI Transaction Submission Errors** - Submission failures
7. **Continuous Submission Failures** - Repeated failure patterns
8. **Build Transaction Errors** - Transaction building issues
9. **Signature Aggregation Failures** - Validator signature problems
10. **Too Many Failures Alert** - Escalated failure scenarios

*Additional alert rules will be added as more Sui services are supported*

### **Notification Channels**

- **PagerDuty**: Critical alerts with escalation
- **Telegram**: Real-time notifications with rich formatting
- **Discord**: Team notifications with webhook integration
- **Webhook**: Custom endpoint integration

---

## ⚙️ **Configuration Details**

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
| **bridges** | `mainnet.target` | Mainnet bridge target | ❌* |
| | `mainnet.public_address` | Mainnet bridge public address | ❌ |
| | `testnet.target` | Testnet bridge target | ❌* |
| | `testnet.public_address` | Testnet bridge public address | ❌ |
| **sui** | `validator` | Validator name for alerts | ❌ |
| **pagerduty** | `integration_key` | PagerDuty integration key | ❌ |
| **telegram** | `bot_token` | Telegram bot token | ❌ |
| | `chat_id` | Telegram chat ID | ❌ |
| **discord** | `webhook_url` | Discord webhook URL | ❌ |

*Required only if you want to monitor Sui Bridge services. If not set, bridge monitoring will be skipped.

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

---

## 🔄 **Maintenance**

### **Updating Services**

To update to newer versions, modify the image tags in `docker-compose.yml` and restart:

```bash
docker compose pull
docker compose up -d
```

### **Configuration Changes**

After modifying `config.yml` or configuration templates:

```bash
docker compose restart prometheus alertmanager grafana
```

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