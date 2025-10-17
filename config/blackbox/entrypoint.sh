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

log_info "Blackbox Exporter entrypoint script started"

# Check if any public addresses are configured
PUBLIC_ADDRESSES_CONFIGURED=false
if [ -n "${SUI_BRIDGE_MAINNET_PUBLIC_ADDRESS:-}" ] || [ -n "${SUI_BRIDGE_TESTNET_PUBLIC_ADDRESS:-}" ]; then
    PUBLIC_ADDRESSES_CONFIGURED=true
    log_info "Public addresses detected - will configure health check probes"
else
    log_info "No public addresses configured - blackbox exporter will run with default config"
fi

log_info "Starting Blackbox Exporter server..."
exec blackbox_exporter --config.file=/etc/blackbox/blackbox.yml "$@"
