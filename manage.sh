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
ENV_FILE=".env"

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

# Check if .env file exists
check_env_file() {
    if [ ! -f "$ENV_FILE" ]; then
        log_error ".env file not found!"
        log_info "Please copy .env.template to .env and configure it:"
        log_info "  cp .env.template .env"
        log_info "  # Edit .env with your configuration"
        exit 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again."
        exit 1
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
    
    check_env_file
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
    
    if command -v docker-compose &> /dev/null; then
        docker-compose -f "$compose_file" restart
    else
        docker compose -f "$compose_file" restart
    fi
    
    log_success "Services restarted"
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

# Clean up
cleanup() {
    local compose_file=$(get_compose_file)
    log_warn "This will remove all containers, volumes, and data. Are you sure? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Cleaning up..."
        
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$compose_file" down -v --remove-orphans
        else
            docker compose -f "$compose_file" down -v --remove-orphans
        fi
        
        rm -rf data/
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
