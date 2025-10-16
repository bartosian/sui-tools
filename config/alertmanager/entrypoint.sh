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
    log_info "Validating Alertmanager configuration..."
    
    if [ -z "${ALERTMANAGER_DEFAULT_WEBHOOK_PORT:-}" ]; then
        log_warn "ALERTMANAGER_DEFAULT_WEBHOOK_PORT not set, using default 3001"
        export ALERTMANAGER_DEFAULT_WEBHOOK_PORT="3001"
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

# Function to check if notification service is configured
check_notification_service() {
    local service="$1"
    local required_vars="$2"
    
    for var in $required_vars; do
        if [ -z "${!var:-}" ]; then
            log_warn "$service notification not configured (missing $var)"
            return 1
        fi
    done
    
    log_info "$service notification is configured"
    return 0
}

# Main execution
main() {
    log_info "Starting Alertmanager entrypoint script..."
    
    # Validate configuration
    validate_config
    
    # Set up environment variables for template substitution
    export ALERTMANAGER_DEFAULT_WEBHOOK_PORT="${ALERTMANAGER_DEFAULT_WEBHOOK_PORT:-3001}"
    
    # Check notification services
    check_notification_service "PagerDuty" "PAGERDUTY_INTEGRATION_KEY"
    check_notification_service "Telegram" "TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID"
    check_notification_service "Discord" "DISCORD_WEBHOOK_URL"
    
    # Generate alertmanager.yml from template
    if [ -f "/etc/alertmanager/alertmanager.yml.template" ]; then
        substitute_template "/etc/alertmanager/alertmanager.yml.template" "/etc/alertmanager/alertmanager.yml"
    else
        log_error "Alertmanager template file not found at /etc/alertmanager/alertmanager.yml.template"
        exit 1
    fi
    
    # Validate generated configuration
    log_info "Validating generated Alertmanager configuration..."
    if amtool check-config /etc/alertmanager/alertmanager.yml; then
        log_info "Alertmanager configuration is valid"
    else
        log_error "Alertmanager configuration validation failed"
        exit 1
    fi
    
    log_info "Starting Alertmanager server..."
    exec /bin/alertmanager --config.file=/etc/alertmanager/alertmanager.yml --storage.path=/alertmanager --web.external-url=http://localhost:9093 --web.listen-address=:9093 --cluster.listen-address= "$@"
}

# Run main function
main "$@"