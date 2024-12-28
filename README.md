# 🚀 **Sui Tools**

<img src="./assets/sui_header.png" alt="Sui Tools Header"/>

This repository provides tools and configurations for **monitoring and managing Sui Nodes**. It includes setup files for **Grafana**, **Prometheus**, and **Alertmanager**, along with pre-configured dashboards for monitoring various **Sui Node services**.

---

## 📦 **Setup and Deployment**

### **1. Clone the Repository**

```bash
git clone https://github.com/sui-network/sui-tools.git
```

### **2. Navigate to the Directory**

```bash
cd sui-tools
```

### **3. Configure Environment Variables**

```bash
cp .env.tmp .env
```

Edit the `.env` file to configure Grafana, Prometheus, Alertmanager, and notification integrations.

### 📑 **Sample `.env` Configuration**

```plaintext
# Grafana Configuration
GF_SECURITY_ADMIN_USER=<admin_user>
GF_SECURITY_ADMIN_PASSWORD=<admin_password>
GF_PORT=3000

# Prometheus Configuration
PROMETHEUS_PORT=9090
PROMETHEUS_TARGET=localhost:9090

# Alertmanager Configuration
ALERTMANAGER_PORT=9093
ALERTMANAGER_TARGET=localhost:9093
ALERTMANAGER_DEFAULT_WEBHOOK_PORT=3001

# Sui Configuration
SUI_BRIDGE_MAINNET_TARGET=localhost:9186
SUI_BRIDGE_TESTNET_TARGET=localhost:9185
SUI_VALIDATOR=<validator_name>

# PagerDuty Integration Key
PAGERDUTY_INTEGRATION_KEY=<your-pagerduty-key>

# Telegram Bot Token
TELEGRAM_BOT_TOKEN=<your-telegram-bot-token>

# Discord Webhook URL
DISCORD_WEBHOOK_URL=<your-discord-webhook-url>
```

> **Note:** If your targets (`SUI_BRIDGE_MAINNET_TARGET`, `SUI_BRIDGE_TESTNET_TARGET`) are HTTPS endpoints, make sure to include the `https://` protocol explicitly in the variable, e.g., `SUI_BRIDGE_MAINNET_TARGET=https://bridge-mainnet.example.com`.

---

### **4. Start the Services**

```bash
docker compose up -d
```

This will deploy the containers for **Grafana**, **Prometheus**, and **Alertmanager**.

- **Grafana**: [http://localhost:3000](http://localhost:3000)  
- **Prometheus**: [http://localhost:9090](http://localhost:9090)  
- **Alertmanager**: [http://localhost:9093](http://localhost:9093)

### **5. Verify Services**

Check logs if something doesn't start properly:

```bash
docker compose logs <service_name>
```

---

## 📊 **Access Pre-Configured Dashboards**

### **Grafana Dashboard**

1. **Sui Bridge Dashboard**  
   - **Description:** Insights into the performance and status of the **Sui Bridge Node**, including metrics for uptime, ETH watcher, SUI watcher, transaction errors, and validator statuses.  
   - **Dashboard File:** [sui_bridge.json](./grafana/dashboards/sui_bridge.json)  
   ![Sui Bridge Dashboard](./assets/sui_bridge.png)

---

## 📡 **Dynamic Alert Configuration**

### **Prometheus Alerts**

Alerts are dynamically generated based on environment variables and split into individual rule files:

```
/prometheus/rules/
└── sui_bridge_alerts.yml
```

### 📑 **Sample Rules**

#### **Sui Bridge Alerts**

- **Node Restarted Alert**  
   Triggers if the node uptime hasn’t increased for 5 minutes.  

- **ETH Watcher Unrecognized Events Alert**  
   Detects if the ETH watcher has encountered unrecognized events in the last 5 minutes.  

- **SUI Watcher Unrecognized Events Alert**  
   Detects if the SUI watcher has encountered unrecognized events in the last 5 minutes.  

- **Zero Voting Rights Alert**  
   Triggers when the validator's authority has zero voting rights.  

- **Error Requests Alert**  
   Detects errors during SUI transaction digest handling.  

- **SUI Transaction Submission Errors Alert**  
   Triggers on errors during SUI transaction submissions.  

- **Continuous SUI Transaction Submission Failures Alert**  
   Detects continuous failures during SUI transaction submissions.  

- **Build SUI Transaction Errors Alert**  
   Alerts if there are errors while building SUI transactions.  

- **Validator Signature Aggregation Failures Alert**  
   Detects failures during validator signature aggregation.  

- **SUI Transaction Submission Too Many Failures Alert**  
   Triggers on repeated failures during SUI transaction submissions.

---

## 🚨 **Notification Integrations**

### **Alertmanager Notification Targets**

Alerts are dynamically routed to the following targets based on `.env` variables:

- **PagerDuty**: Integrated via `PAGERDUTY_INTEGRATION_KEY`.  
- **Telegram**: Configured using `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`.  
- **Discord**: Enabled using `DISCORD_WEBHOOK_URL`.

---

## 🔄 **Restart Services After Configuration Updates**

Whenever `.env` or alert rules change, restart services:

```bash
docker compose restart prometheus alertmanager
```

---

## 🖥️ **Platform-Specific Docker Compose Configurations**

Docker's `network_mode: host` works differently on Linux and macOS, requiring separate configurations.

### ⚙️ **How to Use Platform-Specific Configurations**

- **Linux:** Use `docker-compose.yml` for standard setup.  
- **macOS:** Use `docker-compose.macos.yml` for network_mode: host setup.

---

## 🤝 **Contributing**

Contributions are welcome! If you find an issue or have an improvement, please open a **Pull Request** or create an **Issue**.

---

## 📝 **License**

This repository is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.
