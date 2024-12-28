#!/bin/sh

echo "Generating Alertmanager configuration..."
echo "ALERTMANAGER_DEFAULT_WEBHOOK_PORT=${ALERTMANAGER_DEFAULT_WEBHOOK_PORT}"

# Base configuration
cat <<EOF > /etc/alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  receiver: "default"
  group_wait: 10s
  group_interval: 5m
  repeat_interval: 3h
  routes:
EOF

# Add PagerDuty Receiver if Integration Key is Set
if [ -n "${PAGERDUTY_INTEGRATION_KEY}" ]; then
  echo "Adding PagerDuty receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
    - receiver: "pagerduty"
      continue: true
EOF
fi

# Add Telegram Receiver if Bot Token and Chat ID are Set
if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
  echo "Adding Telegram receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
    - receiver: "telegram"
      continue: true
EOF
fi

# Add Discord Receiver if Webhook URL is Set
if [ -n "${DISCORD_WEBHOOK_URL}" ]; then
  echo "Adding Discord receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
    - receiver: "discord"
      continue: true
EOF
fi

# Receivers section
cat <<EOF >> /etc/alertmanager/alertmanager.yml
receivers:
  - name: "default"
    webhook_configs:
      - url: "http://localhost:${ALERTMANAGER_DEFAULT_WEBHOOK_PORT}"
EOF

# Add PagerDuty Receiver if Integration Key is Set
if [ -n "${PAGERDUTY_INTEGRATION_KEY}" ]; then
  echo "Adding PagerDuty receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
  - name: "pagerduty"
    pagerduty_configs:
      - routing_key: "${PAGERDUTY_INTEGRATION_KEY}"
        send_resolved: true
EOF
fi

# Add Telegram Receiver if Bot Token and Chat ID are Set
if [ -n "${TELEGRAM_BOT_TOKEN}" ] && [ -n "${TELEGRAM_CHAT_ID}" ]; then
  echo "Adding Telegram receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
  - name: "telegram"
    telegram_configs:
      - bot_token: "${TELEGRAM_BOT_TOKEN}"
        chat_id: ${TELEGRAM_CHAT_ID}
        send_resolved: true
EOF
fi

# Add Discord Receiver if Webhook URL is Set
if [ -n "${DISCORD_WEBHOOK_URL}" ]; then
  echo "Adding Discord receiver..."
  cat <<EOF >> /etc/alertmanager/alertmanager.yml
  - name: "discord"
    discord_configs:
      - webhook_url: "${DISCORD_WEBHOOK_URL}"
        send_resolved: true
EOF
fi

echo "Alertmanager configuration generated successfully!"

# Start Alertmanager
exec /bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml "$@"
