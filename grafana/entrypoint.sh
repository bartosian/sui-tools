#!/bin/sh

echo "Starting Grafana entrypoint script..."

SOURCE_DASHBOARD_DIR="/tmp/dashboards"
TARGET_DASHBOARD_DIR="/var/lib/grafana/dashboards"

# Install GitHub plugins
if [ -n "$GF_GITHUB_PLUGINS" ]; then
  echo "Installing GitHub plugins from: $GF_GITHUB_PLUGINS"
  mkdir -p /var/lib/grafana/plugins

  # Split GF_GITHUB_PLUGINS by commas and iterate
  echo "$GF_GITHUB_PLUGINS" | tr ',' '\n' | while read PLUGIN_URL; do
    echo "Downloading and installing plugin from $PLUGIN_URL"
    PLUGIN_NAME=$(basename "$PLUGIN_URL" .zip)
    if curl -L -o "/tmp/$PLUGIN_NAME.zip" "$PLUGIN_URL" && [ -s "/tmp/$PLUGIN_NAME.zip" ]; then
      if unzip "/tmp/$PLUGIN_NAME.zip" -d /var/lib/grafana/plugins; then
        echo "Successfully installed $PLUGIN_NAME"
      else
        echo "Failed to unzip $PLUGIN_NAME. Skipping."
      fi
      rm "/tmp/$PLUGIN_NAME.zip"
    else
      echo "Failed to download $PLUGIN_URL or file is empty. Skipping."
    fi
  done
fi

# Remove all dashboards from the target directory
rm -f "${TARGET_DASHBOARD_DIR}"/*.json
mkdir -p "${TARGET_DASHBOARD_DIR}"

# Add dashboards based on environment variables
if [ -n "${SUI_BRIDGE_TARGET}" ]; then
  echo "Enabling Sui Bridge Dashboard..."
  cp "${SOURCE_DASHBOARD_DIR}/sui_bridge.json" "${TARGET_DASHBOARD_DIR}/" || echo "Failed to copy Sui Bridge Dashboard."

  # Inject SUI_VALIDATOR into the dashboard JSON
  if [ -n "$SUI_VALIDATOR" ]; then
    echo "Injecting SUI_VALIDATOR: $SUI_VALIDATOR into Sui Bridge Dashboard"
    sed -i "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" "${TARGET_DASHBOARD_DIR}/sui_bridge.json"
  else
    echo "SUI_VALIDATOR is not set. Skipping JSON replacement."
  fi
fi

# Start Grafana server
exec grafana server || echo "Grafana server failed to start."