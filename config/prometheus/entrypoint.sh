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
    log_info "Starting Prometheus configuration generation..."
    
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
    
    # Generate prometheus.yml configuration
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

    # Add SUI Bridge Mainnet Scrape Config if configured
    if [ -n "${SUI_BRIDGE_MAINNET_TARGET:-}" ]; then
        log_info "Adding scrape config for SUI Bridge Mainnet: ${SUI_BRIDGE_MAINNET_TARGET}"
        
        MAINNET_SCHEME=$(sanitize_target "${SUI_BRIDGE_MAINNET_TARGET}" | head -n 1)
        MAINNET_TARGET=$(sanitize_target "${SUI_BRIDGE_MAINNET_TARGET}" | tail -n 1)
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_mainnet'
    static_configs:
      - targets: ['${MAINNET_TARGET}']
        labels:
          service: 'sui_bridge'
          environment: 'mainnet'
          configured: 'true'
    scrape_interval: 15s
    metrics_path: /metrics
    scrape_timeout: 10s
    scheme: '${MAINNET_SCHEME}'
    honor_labels: true
    relabel_configs:
      - target_label: instance
        replacement: '${MAINNET_TARGET}'
EOF
    else
        log_warn "SUI_BRIDGE_MAINNET_TARGET not set, skipping mainnet configuration"
    fi
    
    # Add SUI Bridge Testnet Scrape Config if configured
    if [ -n "${SUI_BRIDGE_TESTNET_TARGET:-}" ]; then
        log_info "Adding scrape config for SUI Bridge Testnet: ${SUI_BRIDGE_TESTNET_TARGET}"
        
        TESTNET_SCHEME=$(sanitize_target "${SUI_BRIDGE_TESTNET_TARGET}" | head -n 1)
        TESTNET_TARGET=$(sanitize_target "${SUI_BRIDGE_TESTNET_TARGET}" | tail -n 1)
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_testnet'
    static_configs:
      - targets: ['${TESTNET_TARGET}']
        labels:
          service: 'sui_bridge'
          environment: 'testnet'
          configured: 'true'
    scrape_interval: 15s
    metrics_path: /metrics
    scrape_timeout: 10s
    scheme: '${TESTNET_SCHEME}'
    honor_labels: true
    relabel_configs:
      - target_label: instance
        replacement: '${TESTNET_TARGET}'
EOF
    else
        log_warn "SUI_BRIDGE_TESTNET_TARGET not set, skipping testnet configuration"
    fi
    
    # Add SUI Bridge Mainnet Health Check if configured
    if [ -n "${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS:-}" ]; then
        log_info "Adding health check probe for SUI Bridge Mainnet: ${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}"
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_mainnet_health_check'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - '${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}/metrics_pub_key'
        labels:
          service: 'sui_bridge_health_check'
          environment: 'mainnet'
          configured: 'true'
    scrape_interval: 1m
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
        replacement: '${MAINNET_TARGET}'
      - target_label: __address__
        replacement: '${BLACKBOX_EXPORTER_ADDRESS}'
EOF
    else
        log_warn "SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS not set, skipping mainnet health check"
    fi
    
    # Add SUI Bridge Testnet Health Check if configured
    if [ -n "${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS:-}" ]; then
        log_info "Adding health check probe for SUI Bridge Testnet: ${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}"
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_testnet_health_check'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - '${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}/metrics_pub_key'
        labels:
          service: 'sui_bridge_health_check'
          environment: 'testnet'
          configured: 'true'
    scrape_interval: 1m
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
        replacement: '${TESTNET_TARGET}'
      - target_label: __address__
        replacement: '${BLACKBOX_EXPORTER_ADDRESS}'
EOF
    else
        log_warn "SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS not set, skipping testnet health check"
    fi
    
    # Add SUI Bridge Mainnet Ingress Check if configured
    if [ -n "${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS:-}" ]; then
        log_info "Adding ingress check probe for SUI Bridge Mainnet: ${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}"
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_mainnet_ingress_check'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - '${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}'
        labels:
          service: 'sui_bridge_ingress_check'
          environment: 'mainnet'
          configured: 'true'
    scrape_interval: 1m
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
        replacement: '${MAINNET_TARGET}'
      - target_label: __address__
        replacement: '${BLACKBOX_EXPORTER_ADDRESS}'
EOF
    else
        log_warn "SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS not set, skipping mainnet ingress check"
    fi
    
    # Add SUI Bridge Testnet Ingress Check if configured
    if [ -n "${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS:-}" ]; then
        log_info "Adding ingress check probe for SUI Bridge Testnet: ${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}"
        
        cat <<EOF >> /etc/prometheus/prometheus.yml

  - job_name: 'sui_bridge_testnet_ingress_check'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - '${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}'
        labels:
          service: 'sui_bridge_ingress_check'
          environment: 'testnet'
          configured: 'true'
    scrape_interval: 1m
    scrape_timeout: 10s
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
        replacement: '${TESTNET_TARGET}'
      - target_label: __address__
        replacement: '${BLACKBOX_EXPORTER_ADDRESS}'
EOF
    else
        log_warn "SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS not set, skipping testnet ingress check"
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
    log_info "Validating generated Prometheus configuration..."
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
