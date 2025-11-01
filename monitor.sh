#!/bin/bash

# Sui Tools - Monitoring Stack Management Script
# This script provides convenient commands for managing the monitoring stack

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE_LINUX="docker-compose.yml"
COMPOSE_FILE_MACOS="docker-compose.macos.yml"
CONFIG_FILE="config.yml"

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

log_success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

# Detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "linux"
    fi
}

# Get compose file based on platform
get_compose_file() {
    local platform=$(detect_platform)
    if [ "$platform" = "macos" ]; then
        echo "$COMPOSE_FILE_MACOS"
    else
        echo "$COMPOSE_FILE_LINUX"
    fi
}

# Parse YAML configuration and export environment variables
parse_yaml_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found!"
        log_info "Please copy config.yml.template to config.yml and configure it:"
        log_info "  cp config.yml.template config.yml"
        log_info "  # Edit config.yml with your configuration"
        exit 1
    fi
    
    log_info "Parsing configuration from $CONFIG_FILE..."
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed!"
        log_info "Please install Python 3 to use the dynamic configuration parser"
        exit 1
    fi
    
    # Check if PyYAML is available
    if ! python3 -c "import yaml" &> /dev/null; then
        log_error "PyYAML is required but not installed!"
        log_info "Please install PyYAML: pip3 install PyYAML"
        exit 1
    fi
    
    # Create generated configs directory
    mkdir -p generated_configs
    chmod 755 generated_configs
    
    # Use Python parser to generate Prometheus config, alert rules, and export bridge variables
    log_info "Using Python parser to generate configuration..."
    local parser_output
    parser_output=$(python3 scripts/parse_config.py "$CONFIG_FILE" "generated_configs/prometheus.yml" "generated_configs/alert_rules" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Configuration parsing failed:"
        python3 scripts/parse_config.py "$CONFIG_FILE" "generated_configs/prometheus.yml" "generated_configs/alert_rules" 2>&1
        exit 1
    fi
    
    # Copy generated configs to config directory for container access
    cp generated_configs/prometheus.yml config/prometheus/generated_prometheus.yml
    cp generated_configs/bridges.json config/prometheus/generated_bridges.json
    cp generated_configs/alertmanager.yml config/alertmanager/generated_alertmanager.yml
    
    # Copy validators.json if it exists
    if [ -f "generated_configs/validators.json" ]; then
        cp generated_configs/validators.json config/grafana/generated_validators.json
    fi
    
    # Copy fullnodes.json if it exists
    if [ -f "generated_configs/fullnodes.json" ]; then
        cp generated_configs/fullnodes.json config/grafana/generated_fullnodes.json
    fi
    
    # Ensure alert rules directory exists
    mkdir -p config/prometheus/rules/
    
    # Copy all bridge-specific alert rule files if they exist
    if ls generated_configs/alert_rules/sui_bridge_*_alerts.yml 1> /dev/null 2>&1; then
        cp generated_configs/alert_rules/sui_bridge_*_alerts.yml config/prometheus/rules/
    fi
    
    # Copy all validator-specific alert rule files if they exist
    if ls generated_configs/alert_rules/sui_validator_*_alerts.yml 1> /dev/null 2>&1; then
        cp generated_configs/alert_rules/sui_validator_*_alerts.yml config/prometheus/rules/
    fi
    
    # Copy all fullnode-specific alert rule files if they exist
    if ls generated_configs/alert_rules/sui_fullnode_*_alerts.yml 1> /dev/null 2>&1; then
        cp generated_configs/alert_rules/sui_fullnode_*_alerts.yml config/prometheus/rules/
    fi
    
    # Source the exported variables from Python parser
    # Use a temporary file to avoid shell parsing issues with JSON
    local temp_file=$(mktemp)
    echo "$parser_output" > "$temp_file"
    source "$temp_file"
    rm "$temp_file"
    
    # Function to get value from YAML (for non-bridge configs)
    get_yaml_value() {
        local key="$1"
        local file="$2"
        # Use a simple sed/awk approach to extract values from YAML
        # This handles the specific structure we need without external dependencies
        awk -v key="$key" '
        BEGIN { FS=":"; found=0 }
        {
            # Remove leading/trailing whitespace
            gsub(/^[ \t]+|[ \t]+$/, "", $0)
            gsub(/^[ \t]+|[ \t]+$/, "", $1)
            gsub(/^[ \t]+|[ \t]+$/, "", $2)
            
            # Remove quotes if present
            gsub(/^["\047]|["\047]$/, "", $2)
            
            if ($1 == key && $2 != "") {
                print $2
                found=1
                exit
            }
        }
        END { if (!found) print "" }
        ' "$file"
    }
    
    # Function to get nested value from YAML (for non-bridge configs)
    get_yaml_nested_value() {
        local parent="$1"
        local child="$2"
        local file="$3"
        awk -v parent="$parent" -v child="$child" '
        BEGIN { in_section=0; found=0 }
        {
            # Remove leading/trailing whitespace
            gsub(/^[ \t]+|[ \t]+$/, "", $0)
            
            # Check if we are in the right section
            if ($0 == parent ":") {
                in_section=1
                next
            }
            
            # If we are in the section and find the child key
            if (in_section && match($0, "^[ \t]*" child "[ \t]*:")) {
                # Extract everything after the colon
                value = substr($0, RSTART + RLENGTH)
                gsub(/^[ \t]+|[ \t]+$/, "", value)
                gsub(/^["\047]|["\047]$/, "", value)
                if (value != "") {
                    print value
                    found=1
                    exit
                }
            }
            
            # If we hit another top-level key, we are out of the section
            if (in_section && $0 ~ /^[a-zA-Z]/ && $0 !~ /^[ \t]/ && !match($0, ":")) {
                in_section=0
            }
        }
        END { if (!found) print "" }
        ' "$file"
    }
    
    # Export Grafana variables
    export GF_SECURITY_ADMIN_USER=$(get_yaml_nested_value "grafana" "admin_user" "$CONFIG_FILE")
    export GF_SECURITY_ADMIN_PASSWORD=$(get_yaml_nested_value "grafana" "admin_password" "$CONFIG_FILE")
    export GF_PORT=$(get_yaml_nested_value "grafana" "port" "$CONFIG_FILE")
    
    # Export Prometheus variables
    export PROMETHEUS_PORT=$(get_yaml_nested_value "prometheus" "port" "$CONFIG_FILE")
    export PROMETHEUS_TARGET=$(get_yaml_nested_value "prometheus" "target" "$CONFIG_FILE")
    
    # Export Alertmanager variables
    export ALERTMANAGER_PORT=$(get_yaml_nested_value "alertmanager" "port" "$CONFIG_FILE")
    export ALERTMANAGER_TARGET=$(get_yaml_nested_value "alertmanager" "target" "$CONFIG_FILE")
    export ALERTMANAGER_DEFAULT_WEBHOOK_PORT=$(get_yaml_nested_value "alertmanager" "default_webhook_port" "$CONFIG_FILE")
    
    # Note: SUI_VALIDATOR is now exported by the Python parser
    
    # Export notification variables
    export PAGERDUTY_INTEGRATION_KEY=$(get_yaml_nested_value "pagerduty" "integration_key" "$CONFIG_FILE")
    export TELEGRAM_BOT_TOKEN=$(get_yaml_nested_value "telegram" "bot_token" "$CONFIG_FILE")
    export TELEGRAM_CHAT_ID=$(get_yaml_nested_value "telegram" "chat_id" "$CONFIG_FILE")
    export DISCORD_WEBHOOK_URL=$(get_yaml_nested_value "discord" "webhook_url" "$CONFIG_FILE")
    
    # Set defaults for empty values
    export GF_PORT="${GF_PORT:-3000}"
    export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
    export ALERTMANAGER_PORT="${ALERTMANAGER_PORT:-9093}"
    export ALERTMANAGER_DEFAULT_WEBHOOK_PORT="${ALERTMANAGER_DEFAULT_WEBHOOK_PORT:-3001}"
    export PROMETHEUS_TARGET="${PROMETHEUS_TARGET:-localhost:9090}"
    export ALERTMANAGER_TARGET="${ALERTMANAGER_TARGET:-localhost:9093}"
    
    log_success "Configuration loaded successfully"
    log_info "Parsed $SUI_BRIDGES_COUNT bridge(s)"
    if [ -n "${SUI_VALIDATORS_COUNT:-}" ] && [ "$SUI_VALIDATORS_COUNT" -gt 0 ]; then
        log_info "Parsed $SUI_VALIDATORS_COUNT validator(s)"
    fi
    if [ -n "${SUI_FULLNODES_COUNT:-}" ] && [ "$SUI_FULLNODES_COUNT" -gt 0 ]; then
        log_info "Parsed $SUI_FULLNODES_COUNT fullnode(s)"
    fi
}

# Detect OS and package manager
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID:-linux}"
    else
        echo "linux"
    fi
}

# Install Docker on different systems
install_docker() {
    local os=$(detect_os)
    
    log_info "Installing Docker..."
    
    case "$os" in
        macos)
            if ! command -v brew &> /dev/null; then
                log_error "Homebrew is not installed. Please install Homebrew first:"
                log_info "Visit: https://brew.sh"
                return 1
            fi
            brew install --cask docker
            log_info "Docker installed. Please start Docker Desktop from Applications."
            ;;
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg lsb-release
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/${os}/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${os} $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            log_success "Docker installed successfully"
            ;;
        centos|rhel|fedora)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo systemctl start docker
            sudo systemctl enable docker
            log_success "Docker installed successfully"
            ;;
        *)
            log_error "Unsupported OS: $os"
            log_info "Please install Docker manually from: https://docs.docker.com/get-docker/"
            return 1
            ;;
    esac
}

# Install Python3 and pip
install_python() {
    local os=$(detect_os)
    
    log_info "Installing Python3..."
    
    case "$os" in
        macos)
            if ! command -v brew &> /dev/null; then
                log_error "Homebrew is not installed. Please install Homebrew first:"
                log_info "Visit: https://brew.sh"
                return 1
            fi
            brew install python3
            ;;
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip
            ;;
        centos|rhel|fedora)
            sudo yum install -y python3 python3-pip
            ;;
        *)
            log_error "Unsupported OS: $os"
            log_info "Please install Python3 manually"
            return 1
            ;;
    esac
    
    log_success "Python3 installed successfully"
}

# Install PyYAML
install_pyyaml() {
    log_info "Installing PyYAML..."
    
    if command -v pip3 &> /dev/null; then
        pip3 install PyYAML 2>/dev/null || pip3 install PyYAML --break-system-packages
    elif command -v pip &> /dev/null; then
        pip install PyYAML 2>/dev/null || pip install PyYAML --break-system-packages
    else
        log_error "pip is not available. Please install Python and pip first."
        return 1
    fi
    
    log_success "PyYAML installed successfully"
}

# Check if required tools are installed and offer to install them
check_dependencies() {
    local missing_deps=()
    local need_docker=false
    local need_python=false
    local need_pyyaml=false
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
        need_docker=true
    fi
    
    # Check Docker Compose (plugin or standalone)
    if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
        if ! $need_docker; then
            missing_deps+=("docker-compose")
        fi
    fi
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
        need_python=true
    fi
    
    # Check PyYAML
    if command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml" 2>/dev/null; then
            missing_deps+=("PyYAML")
            need_pyyaml=true
        fi
    fi
    
    # If no missing dependencies, return success
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    # Report missing dependencies
    log_error "Missing required dependencies: ${missing_deps[*]}"
    echo ""
    log_info "Would you like to install the missing dependencies automatically? (y/n)"
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled. Please install the missing dependencies manually."
        log_info ""
        log_info "Installation guides:"
        log_info "  - Docker: https://docs.docker.com/get-docker/"
        log_info "  - Python3: https://www.python.org/downloads/"
        log_info "  - PyYAML: pip3 install PyYAML"
        exit 1
    fi
    
    # Install missing dependencies
    if $need_docker; then
        install_docker || exit 1
    fi
    
    if $need_python; then
        install_python || exit 1
    fi
    
    if $need_pyyaml; then
        install_pyyaml || exit 1
    fi
    
    log_success "All dependencies installed successfully!"
    
    # Verify Docker is running (especially important on macOS)
    if $need_docker && [[ "$(detect_os)" == "macos" ]]; then
        log_info ""
        log_info "⚠️  On macOS, Docker Desktop needs to be started manually."
        log_info "Please open Docker Desktop from Applications, then run this script again."
        exit 0
    fi
}

# Create data directories
create_data_directories() {
    log_info "Creating data directories..."
    mkdir -p data/grafana data/prometheus data/alertmanager
    log_success "Data directories created"
}

# Start services
start_services() {
    local compose_file=$(get_compose_file)
    log_info "Starting services using $compose_file..."
    
    parse_yaml_config
    check_dependencies
    create_data_directories
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" up -d
    else
        docker compose -f "$compose_file" up -d
    fi
    
    log_success "Services started successfully!"
    log_info "Access your services:"
    log_info "  Grafana: http://localhost:3000"
    log_info "  Prometheus: http://localhost:9090"
    log_info "  Alertmanager: http://localhost:9093"
}

# Stop services
stop_services() {
    local compose_file=$(get_compose_file)
    log_info "Stopping services..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" down
    else
        docker compose -f "$compose_file" down
    fi
    
    log_success "Services stopped"
}

# Restart services
restart_services() {
    local compose_file=$(get_compose_file)
    log_info "Restarting services..."
    
    # Clean up old generated files before regenerating
    cleanup_generated_files
    
    # Regenerate configs from config.yml
    parse_yaml_config
    
    # Use down + up to ensure volume changes are picked up
    log_info "Stopping services to reload configuration..."
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" down
        docker-compose -f "$compose_file" up -d
    else
        docker compose -f "$compose_file" down
        docker compose -f "$compose_file" up -d
    fi
    
    log_success "Services restarted with updated configuration"
}

# Show service status
show_status() {
    local compose_file=$(get_compose_file)
    log_info "Service status:"
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" ps
    else
        docker compose -f "$compose_file" ps
    fi
}

# Show service logs
show_logs() {
    local service="$1"
    local compose_file=$(get_compose_file)
    
    if [ -z "$service" ]; then
        log_error "Please specify a service name (grafana, prometheus, alertmanager)"
        exit 1
    fi
    
    log_info "Showing logs for $service..."
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" logs -f "$service"
    else
        docker compose -f "$compose_file" logs -f "$service"
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    # Check Prometheus config
    log_info "Validating Prometheus configuration..."
    if command -v docker-compose &> /dev/null; then
        docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
    else
        docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
    fi
    
    # Check Alertmanager config
    log_info "Validating Alertmanager configuration..."
    if command -v docker-compose &> /dev/null; then
        docker-compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
    else
        docker compose exec alertmanager amtool check-config /etc/alertmanager/alertmanager.yml
    fi
    
    log_success "Configuration validation completed"
}

# Backup data
backup_data() {
    local backup_file="sui-monitoring-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    log_info "Creating backup: $backup_file"
    
    tar -czf "$backup_file" data/
    log_success "Backup created: $backup_file"
}

# Restore data
restore_data() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Please specify a backup file"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_info "Restoring from backup: $backup_file"
    tar -xzf "$backup_file"
    log_success "Data restored from backup"
}

# Clean up generated files
cleanup_generated_files() {
    log_info "Cleaning up generated configuration files..."
    rm -rf generated_configs/
    rm -f config/prometheus/generated_prometheus.yml
    rm -f config/prometheus/generated_bridges.json
    rm -f config/alertmanager/generated_alertmanager.yml
    rm -f config/grafana/generated_validators.json
    rm -f config/grafana/generated_fullnodes.json
    rm -f config/prometheus/rules/sui_bridge_*_alerts.yml
    rm -f config/prometheus/rules/sui_validator_*_alerts.yml
    rm -f config/prometheus/rules/sui_fullnode_*_alerts.yml
}

# Clean up
cleanup() {
    local compose_file=$(get_compose_file)
    log_warn "This will remove all containers, volumes, and data. Are you sure? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleaning up..."
        
        parse_yaml_config
        
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$compose_file" down -v --remove-orphans
        else
            docker compose -f "$compose_file" down -v --remove-orphans
        fi
        
        rm -rf data/
        cleanup_generated_files
        log_success "Cleanup completed"
    else
        log_info "Cleanup cancelled"
    fi
}

# Show help
show_help() {
    echo "Sui Tools - Monitoring Stack Management"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  start                 Start all services"
    echo "  stop                  Stop all services"
    echo "  restart               Restart all services"
    echo "  status                Show service status"
    echo "  logs <service>        Show logs for a service (grafana|prometheus|alertmanager)"
    echo "  validate              Validate configuration files"
    echo "  backup                Create a backup of data"
    echo "  restore <file>        Restore data from backup"
    echo "  cleanup               Remove all containers and data"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs prometheus"
    echo "  $0 backup"
    echo "  $0 restore backup.tar.gz"
}

# Main script logic
main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        validate)
            validate_config
            ;;
        backup)
            backup_data
            ;;
        restore)
            restore_data "$2"
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
