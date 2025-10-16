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
    log_info "Validating Prometheus configuration..."
    
    if [ -z "${PROMETHEUS_TARGET:-}" ]; then
        log_error "PROMETHEUS_TARGET is not set"
        exit 1
    fi
    
    if [ -z "${ALERTMANAGER_TARGET:-}" ]; then
        log_error "ALERTMANAGER_TARGET is not set"
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

# Function to sanitize target URLs
sanitize_target() {
    local target="$1"
    if echo "$target" | grep -q '^https://'; then
        echo "https"
        echo "$target" | sed 's|^https://||'
    elif echo "$target" | grep -q '^http://'; then
        echo "http"
        echo "$target" | sed 's|^http://||'
    else
        echo "http"
        echo "$target"
    fi
}

# Main execution
main() {
    log_info "Starting Prometheus entrypoint script..."
    
    # Validate configuration
    validate_config
    
    # Set up environment variables for template substitution
    export PROMETHEUS_TARGET="${PROMETHEUS_TARGET:-localhost:9090}"
    export ALERTMANAGER_TARGET="${ALERTMANAGER_TARGET:-localhost:9093}"
    
    # Handle SUI Bridge targets
    if [ -n "${SUI_BRIDGE_MAINNET_TARGET:-}" ]; then
        log_info "Configuring SUI Bridge Mainnet target: $SUI_BRIDGE_MAINNET_TARGET"
        MAINNET_SCHEME=$(sanitize_target "$SUI_BRIDGE_MAINNET_TARGET" | head -n 1)
        MAINNET_TARGET=$(sanitize_target "$SUI_BRIDGE_MAINNET_TARGET" | tail -n 1)
        export SUI_BRIDGE_MAINNET_TARGET="$MAINNET_TARGET"
        export SUI_BRIDGE_MAINNET_SCHEME="$MAINNET_SCHEME"
    else
        log_warn "SUI_BRIDGE_MAINNET_TARGET not set, skipping mainnet configuration"
    fi
    
    if [ -n "${SUI_BRIDGE_TESTNET_TARGET:-}" ]; then
        log_info "Configuring SUI Bridge Testnet target: $SUI_BRIDGE_TESTNET_TARGET"
        TESTNET_SCHEME=$(sanitize_target "$SUI_BRIDGE_TESTNET_TARGET" | head -n 1)
        TESTNET_TARGET=$(sanitize_target "$SUI_BRIDGE_TESTNET_TARGET" | tail -n 1)
        export SUI_BRIDGE_TESTNET_TARGET="$TESTNET_TARGET"
        export SUI_BRIDGE_TESTNET_SCHEME="$TESTNET_SCHEME"
    else
        log_warn "SUI_BRIDGE_TESTNET_TARGET not set, skipping testnet configuration"
    fi
    
    # Substitute SUI_VALIDATOR in alert rules if set
    if [ -n "${SUI_VALIDATOR:-}" ]; then
        log_info "Substituting SUI_VALIDATOR: $SUI_VALIDATOR in alert rules"
        find /etc/prometheus/rules -name "*.yml" -exec sed -i "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" {} \;
    else
        log_warn "SUI_VALIDATOR is not set, skipping substitution in rules"
    fi
    
    # Generate prometheus.yml from template
    if [ -f "/etc/prometheus/prometheus.yml.template" ]; then
        substitute_template "/etc/prometheus/prometheus.yml.template" "/etc/prometheus/prometheus.yml"
    else
        log_error "Prometheus template file not found at /etc/prometheus/prometheus.yml.template"
        exit 1
    fi
    
    # Validate generated configuration
    log_info "Validating generated Prometheus configuration..."
    if promtool check config /etc/prometheus/prometheus.yml; then
        log_info "Prometheus configuration is valid"
    else
        log_error "Prometheus configuration validation failed"
        exit 1
    fi
    
    # Validate alert rules
    log_info "Validating alert rules..."
    if promtool check rules /etc/prometheus/rules/*.yml; then
        log_info "Alert rules are valid"
    else
        log_error "Alert rules validation failed"
        exit 1
    fi
    
    log_info "Starting Prometheus server..."
    exec prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.console.libraries=/etc/prometheus/console_libraries --web.console.templates=/etc/prometheus/consoles --web.enable-lifecycle --web.enable-admin-api "$@"
}

# Run main function
main "$@"