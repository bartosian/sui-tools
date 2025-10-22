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

# Check if any bridge targets are configured by checking the generated bridges config file
BRIDGE_TARGETS_CONFIGURED=false
if [ -f "/etc/sui-tools/generated_configs/bridges.json" ]; then
    # Check if the file is not empty and contains at least one bridge (simple check for opening bracket)
    if grep -q '\[' "/etc/sui-tools/generated_configs/bridges.json" 2>/dev/null && \
       [ "$(cat /etc/sui-tools/generated_configs/bridges.json | grep -o '"alias"' | wc -l)" -gt 0 ]; then
        BRIDGE_COUNT=$(cat /etc/sui-tools/generated_configs/bridges.json | grep -o '"alias"' | wc -l | tr -d ' ')
        BRIDGE_TARGETS_CONFIGURED=true
        log_info "Bridge targets detected ($BRIDGE_COUNT bridges) - will deploy bridge dashboard"
    else
        log_info "No bridge targets configured - skipping bridge dashboard deployment"
    fi
else
    log_info "No bridge configuration file found - skipping bridge dashboard deployment"
fi

# Check if any validator targets are configured by checking the generated validators config file
VALIDATOR_TARGETS_CONFIGURED=false
if [ -f "/etc/grafana/provisioning/generated_validators.json" ]; then
    # Check if the file is not empty and contains at least one validator
    if grep -q '\[' "/etc/grafana/provisioning/generated_validators.json" 2>/dev/null && \
       [ "$(cat /etc/grafana/provisioning/generated_validators.json | grep -o '"alias"' | wc -l)" -gt 0 ]; then
        VALIDATOR_COUNT=$(cat /etc/grafana/provisioning/generated_validators.json | grep -o '"alias"' | wc -l | tr -d ' ')
        VALIDATOR_TARGETS_CONFIGURED=true
        log_info "Validator targets detected ($VALIDATOR_COUNT validators) - will deploy validator dashboard"
    else
        log_info "No validator targets configured - skipping validator dashboard deployment"
    fi
else
    log_info "No validator configuration file found - skipping validator dashboard deployment"
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
            
            # Skip validator dashboard if no validator targets are configured
            if [[ "$filename" == *"validator"* ]] && [ "$VALIDATOR_TARGETS_CONFIGURED" = false ]; then
                log_info "Skipping validator dashboard: $filename (no validator targets configured)"
                continue
            fi
            
            log_info "Processing dashboard: $filename"
            
            # Use a safer substitution method with different delimiter
            # Substitute SUI_VALIDATOR placeholder with actual value using | as delimiter
            sed "s|\${SUI_VALIDATOR}|$SUI_VALIDATOR|g" "$dashboard" > "/tmp/processed_dashboards/$filename"
            
            # Also substitute the constant variable value using | as delimiter
            sed -i "s|\"\$SUI_VALIDATOR\"|\"$SUI_VALIDATOR\"|g" "/tmp/processed_dashboards/$filename"
            
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
    if [ "$BRIDGE_TARGETS_CONFIGURED" = true ] || [ "$VALIDATOR_TARGETS_CONFIGURED" = true ]; then
        log_info "Targets configured but SUI_VALIDATOR not set - deploying dashboards without substitution"
        
        # Create a temporary directory for processed dashboards
        mkdir -p /tmp/processed_dashboards
        
        # Copy dashboards based on what's configured
        for dashboard in /etc/dashboards/*.json; do
            if [ -f "$dashboard" ]; then
                filename=$(basename "$dashboard")
                
                # Skip bridge dashboard if not configured
                if [[ "$filename" == *"bridge"* ]] && [ "$BRIDGE_TARGETS_CONFIGURED" = false ]; then
                    log_info "Skipping bridge dashboard: $filename (no bridge targets configured)"
                    continue
                fi
                
                # Skip validator dashboard if not configured
                if [[ "$filename" == *"validator"* ]] && [ "$VALIDATOR_TARGETS_CONFIGURED" = false ]; then
                    log_info "Skipping validator dashboard: $filename (no validator targets configured)"
                    continue
                fi
                
                cp "$dashboard" /tmp/processed_dashboards/
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
        log_info "No targets configured - using default provisioning (no dashboards)"
    fi
fi

log_info "Starting Grafana server..."
exec /run.sh "$@"
