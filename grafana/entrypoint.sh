#!/bin/bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "Grafana entrypoint script started"

# Check if any bridge targets are configured
BRIDGE_TARGETS_CONFIGURED=false
if [ -n "${SUI_BRIDGE_MAINNET_TARGET:-}" ] || [ -n "${SUI_BRIDGE_TESTNET_TARGET:-}" ]; then
    BRIDGE_TARGETS_CONFIGURED=true
    log_info "Bridge targets detected - will deploy bridge dashboard"
else
    log_info "No bridge targets configured - skipping bridge dashboard deployment"
fi

# Process dashboard templates - substitute SUI_VALIDATOR
if [ -n "${SUI_VALIDATOR:-}" ]; then
    log_info "Substituting SUI_VALIDATOR: $SUI_VALIDATOR in dashboards"
    
    # Create a temporary directory for processed dashboards
    mkdir -p /tmp/processed_dashboards
    
    # Process each dashboard JSON file
    for dashboard in /etc/dashboards/*.json; do
        if [ -f "$dashboard" ]; then
            filename=$(basename "$dashboard")
            
            # Skip bridge dashboard if no bridge targets are configured
            if [[ "$filename" == *"bridge"* ]] && [ "$BRIDGE_TARGETS_CONFIGURED" = false ]; then
                log_info "Skipping bridge dashboard: $filename (no bridge targets configured)"
                continue
            fi
            
            log_info "Processing dashboard: $filename"
            
            # Substitute SUI_VALIDATOR placeholder with actual value
            sed "s/\${SUI_VALIDATOR}/$SUI_VALIDATOR/g" "$dashboard" > "/tmp/processed_dashboards/$filename"
            
            # Also substitute the constant variable value
            sed -i "s/\"\$SUI_VALIDATOR\"/\"$SUI_VALIDATOR\"/g" "/tmp/processed_dashboards/$filename"
            
            # Substitute public address variables if they are set
            if [ -n "${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS:-}" ]; then
                sed -i "s/\${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}/$SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS/g" "/tmp/processed_dashboards/$filename"
                log_info "Substituted SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS: $SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS"
            fi
            
            if [ -n "${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS:-}" ]; then
                sed -i "s/\${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}/$SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS/g" "/tmp/processed_dashboards/$filename"
                log_info "Substituted SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS: $SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS"
            fi
            
            log_info "Dashboard processed: $filename"
        fi
    done
    
    # Create a new provisioning file that points to processed dashboards
    mkdir -p /tmp/grafana_provisioning/dashboards
    cat > /tmp/grafana_provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /tmp/processed_dashboards
EOF
    
    # Copy datasources provisioning
    if [ -d "/etc/grafana/provisioning/datasources" ]; then
        cp -r /etc/grafana/provisioning/datasources /tmp/grafana_provisioning/
    fi
    
    # Update Grafana to use our processed provisioning
    export GF_PATHS_PROVISIONING=/tmp/grafana_provisioning
    log_info "Updated Grafana provisioning path to use processed dashboards"
else
    log_warn "SUI_VALIDATOR not set, skipping dashboard substitution"
    
    # Even without SUI_VALIDATOR, we still need to conditionally deploy dashboards
    if [ "$BRIDGE_TARGETS_CONFIGURED" = true ]; then
        log_info "Bridge targets configured but SUI_VALIDATOR not set - deploying dashboards without substitution"
        
        # Create a temporary directory for processed dashboards
        mkdir -p /tmp/processed_dashboards
        
        # Copy all dashboards (including bridge dashboard)
        cp /etc/dashboards/*.json /tmp/processed_dashboards/
        
        # Process public address variables if they are set
        for dashboard in /tmp/processed_dashboards/*.json; do
            if [ -f "$dashboard" ]; then
                if [ -n "${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS:-}" ]; then
                    sed -i "s/\${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS}/$SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS/g" "$dashboard"
                    log_info "Substituted SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS: $SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS"
                fi
                
                if [ -n "${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS:-}" ]; then
                    sed -i "s/\${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS}/$SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS/g" "$dashboard"
                    log_info "Substituted SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS: $SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS"
                fi
            fi
        done
        
        # Create a new provisioning file that points to processed dashboards
        mkdir -p /tmp/grafana_provisioning/dashboards
        cat > /tmp/grafana_provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /tmp/processed_dashboards
EOF
        
        # Copy datasources provisioning
        if [ -d "/etc/grafana/provisioning/datasources" ]; then
            cp -r /etc/grafana/provisioning/datasources /tmp/grafana_provisioning/
        fi
        
        # Update Grafana to use our processed provisioning
        export GF_PATHS_PROVISIONING=/tmp/grafana_provisioning
        log_info "Updated Grafana provisioning path to use processed dashboards"
    else
        log_info "No bridge targets configured - using default provisioning (no bridge dashboard)"
    fi
fi

log_info "Starting Grafana server..."
exec /run.sh "$@"
