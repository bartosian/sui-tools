#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration validation
validate_config() {
    log_info "Validating Grafana configuration..."
    
    if [ -z "${GF_SECURITY_ADMIN_USER:-}" ]; then
        log_error "GF_SECURITY_ADMIN_USER is not set"
        exit 1
    fi
    
    if [ -z "${GF_SECURITY_ADMIN_PASSWORD:-}" ]; then
        log_error "GF_SECURITY_ADMIN_PASSWORD is not set"
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# Function to substitute environment variables in template files
substitute_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        log_error "Template file $template_file not found"
        return 1
    fi
    
    log_info "Substituting variables in $template_file -> $output_file"
    
    # Create output directory if it doesn't exist
    mkdir -p "$(dirname "$output_file")"
    
    # Substitute environment variables
    envsubst < "$template_file" > "$output_file"
    
    if [ $? -eq 0 ]; then
        log_info "Successfully generated $output_file"
    else
        log_error "Failed to generate $output_file"
        return 1
    fi
}

# Function to install GitHub plugins
install_github_plugins() {
    if [ -n "${GF_GITHUB_PLUGINS:-}" ]; then
        log_info "Installing GitHub plugins from: $GF_GITHUB_PLUGINS"
        mkdir -p /var/lib/grafana/plugins

        # Split GF_GITHUB_PLUGINS by commas and iterate
        echo "$GF_GITHUB_PLUGINS" | tr ',' '\n' | while read -r PLUGIN_URL; do
            if [ -n "$PLUGIN_URL" ]; then
                log_info "Downloading and installing plugin from $PLUGIN_URL"
                PLUGIN_NAME=$(basename "$PLUGIN_URL" .zip)
                
                if curl -L -o "/tmp/$PLUGIN_NAME.zip" "$PLUGIN_URL" && [ -s "/tmp/$PLUGIN_NAME.zip" ]; then
                    if unzip "/tmp/$PLUGIN_NAME.zip" -d /var/lib/grafana/plugins; then
                        log_info "Successfully installed $PLUGIN_NAME"
                    else
                        log_error "Failed to unzip $PLUGIN_NAME. Skipping."
                    fi
                    rm "/tmp/$PLUGIN_NAME.zip"
                else
                    log_error "Failed to download $PLUGIN_URL or file is empty. Skipping."
                fi
            fi
        done
    fi
}

# Function to setup dashboards
setup_dashboards() {
    local SOURCE_DASHBOARD_DIR="/tmp/dashboards"
    local TARGET_DASHBOARD_DIR="/var/lib/grafana/dashboards"
    local DEFAULT_DASHBOARD_DIR="/var/lib/grafana/default-dashboards"

    # Create dashboard directories
    mkdir -p "$TARGET_DASHBOARD_DIR"
    mkdir -p "$DEFAULT_DASHBOARD_DIR"

    # Remove all dashboards from the target directory
    rm -f "${TARGET_DASHBOARD_DIR}"/*.json

    # Add dashboards based on environment variables
    if [ -n "${SUI_BRIDGE_MAINNET_TARGET:-}" ] || [ -n "${SUI_BRIDGE_TESTNET_TARGET:-}" ]; then
        log_info "Enabling Sui Bridge Dashboard..."
        
        if [ -f "${SOURCE_DASHBOARD_DIR}/sui_bridge.json" ]; then
            cp "${SOURCE_DASHBOARD_DIR}/sui_bridge.json" "${TARGET_DASHBOARD_DIR}/"
            
            # Inject SUI_VALIDATOR into the dashboard JSON
            if [ -n "${SUI_VALIDATOR:-}" ]; then
                log_info "Injecting SUI_VALIDATOR: $SUI_VALIDATOR into Sui Bridge Dashboard"
                sed -i "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" "${TARGET_DASHBOARD_DIR}/sui_bridge.json"
            else
                log_warn "SUI_VALIDATOR is not set. Skipping JSON replacement."
            fi
            
            log_info "Sui Bridge Dashboard copied successfully"
        else
            log_error "Sui Bridge Dashboard file not found at ${SOURCE_DASHBOARD_DIR}/sui_bridge.json"
        fi
    else
        log_warn "No SUI Bridge targets detected. Skipping dashboard setup."
    fi
}

# Main execution
main() {
    log_info "Starting Grafana entrypoint script..."
    
    # Validate configuration
    validate_config
    
    # Set up environment variables for template substitution
    export PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
    export ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"
    
    # Install GitHub plugins if configured
    install_github_plugins
    
    # Setup dashboards
    setup_dashboards
    
    # Generate provisioning configurations from templates
    if [ -f "/etc/grafana/provisioning/datasources/datasources.yml.template" ]; then
        substitute_template "/etc/grafana/provisioning/datasources/datasources.yml.template" "/etc/grafana/provisioning/datasources/datasources.yml"
    else
        log_warn "Datasources template not found, using existing configuration"
    fi
    
    if [ -f "/etc/grafana/provisioning/dashboards/dashboards.yml.template" ]; then
        substitute_template "/etc/grafana/provisioning/dashboards/dashboards.yml.template" "/etc/grafana/provisioning/dashboards/dashboards.yml"
    else
        log_warn "Dashboards template not found, using existing configuration"
    fi
    
    # Set proper permissions
    chown -R grafana:grafana /var/lib/grafana
    chmod -R 755 /var/lib/grafana
    
    log_info "Starting Grafana server..."
    exec grafana server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana --packaging=docker "$@"
}

# Run main function
main "$@"