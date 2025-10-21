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

# Main execution
main() {
    log_info "Starting Prometheus configuration setup..."
    
    # Set defaults
    export PROMETHEUS_TARGET="${PROMETHEUS_TARGET:-localhost:9090}"
    export ALERTMANAGER_TARGET="${ALERTMANAGER_TARGET:-localhost:9093}"
    
    # Determine blackbox-exporter address based on environment
    if [ -n "${PROMETHEUS_TARGET}" ] && [[ "${PROMETHEUS_TARGET}" == *"prometheus:9090"* ]]; then
        # macOS environment - use service name
        BLACKBOX_EXPORTER_ADDRESS="blackbox-exporter:9115"
    else
        # Linux environment - use localhost
        BLACKBOX_EXPORTER_ADDRESS="localhost:9115"
    fi
    
    # Check if pre-generated prometheus.yml exists
    if [ -f "/config/generated_prometheus.yml" ]; then
        log_info "Using pre-generated Prometheus configuration..."
        
        # Copy pre-generated config and substitute environment variables
        cp /config/generated_prometheus.yml /etc/prometheus/prometheus.yml
        
        # Substitute environment variables in the config
        sed -i "s/\${ALERTMANAGER_TARGET}/$ALERTMANAGER_TARGET/g" /etc/prometheus/prometheus.yml
        sed -i "s/\${PROMETHEUS_TARGET}/$PROMETHEUS_TARGET/g" /etc/prometheus/prometheus.yml
        sed -i "s/\${BLACKBOX_EXPORTER_ADDRESS}/$BLACKBOX_EXPORTER_ADDRESS/g" /etc/prometheus/prometheus.yml
        
        log_info "Prometheus configuration updated with environment variables"
    else
        log_warn "Pre-generated prometheus.yml not found, using fallback configuration..."
        
        # Generate basic prometheus.yml configuration
        cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'sui-monitoring'
    replica: 'prometheus-1'

rule_files:
  - "/etc/prometheus/rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['${ALERTMANAGER_TARGET}']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['${PROMETHEUS_TARGET}']
    scrape_interval: 5s
    metrics_path: /metrics
EOF
    fi
    
    # Copy rules to writable location and substitute SUI_VALIDATOR
    mkdir -p /etc/prometheus/rules
    if ls /config/rules/*.yml 1> /dev/null 2>&1; then
        cp /config/rules/*.yml /etc/prometheus/rules/
        
        if [ -n "${SUI_VALIDATOR:-}" ]; then
            log_info "Substituting SUI_VALIDATOR: $SUI_VALIDATOR in alert rules"
            find /etc/prometheus/rules -name "*.yml" -type f -exec sed -i "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" {} \;
        else
            log_warn "SUI_VALIDATOR is not set, skipping substitution in rules"
        fi
    fi
    
    # Validate generated configuration
    log_info "Validating Prometheus configuration..."
    if promtool check config /etc/prometheus/prometheus.yml; then
        log_info "Prometheus configuration is valid"
    else
        log_error "Prometheus configuration validation failed"
        cat /etc/prometheus/prometheus.yml
        exit 1
    fi
    
    # Validate alert rules if they exist
    if ls /etc/prometheus/rules/*.yml 1> /dev/null 2>&1; then
        log_info "Validating alert rules..."
        if promtool check rules /etc/prometheus/rules/*.yml; then
            log_info "Alert rules are valid"
        else
            log_error "Alert rules validation failed"
            exit 1
        fi
    fi
    
    log_info "Starting Prometheus server..."
    exec prometheus \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --web.console.libraries=/etc/prometheus/console_libraries \
        --web.console.templates=/etc/prometheus/consoles \
        --web.enable-lifecycle \
        --web.enable-admin-api \
        "$@"
}

# Run main function
main "$@"
