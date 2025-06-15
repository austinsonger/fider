#!/bin/bash
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FIDER: $1"
}

# Function to wait for Tor proxy
wait_for_tor() {
    local max_attempts=30
    local attempt=1
    
    log "Waiting for Tor proxy to be available..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl --socks5 tor:9050 --connect-timeout 5 http://3g2upl4pq6kufc4m.onion >/dev/null 2>&1; then
            log "Tor proxy is ready!"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: Tor proxy not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Tor proxy not available within expected time"
    return 1
}

# Function to wait for database
wait_for_database() {
    local max_attempts=30
    local attempt=1
    
    log "Waiting for database to be available..."
    
    while [ $attempt -le $max_attempts ]; do
        if ./fider ping >/dev/null 2>&1; then
            log "Database is ready!"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: Database not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Database not available within expected time"
    return 1
}

# Function to setup environment for Tor
setup_tor_environment() {
    log "Setting up Tor environment..."
    
    # Set proxy environment variables
    export HTTP_PROXY="${HTTP_PROXY:-socks5://tor:9050}"
    export HTTPS_PROXY="${HTTPS_PROXY:-socks5://tor:9050}"
    export http_proxy="${HTTP_PROXY}"
    export https_proxy="${HTTPS_PROXY}"
    
    # Ensure NO_PROXY includes internal services
    export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,postgres,tor}"
    export no_proxy="${NO_PROXY}"
    
    log "Proxy configuration:"
    log "  HTTP_PROXY: $HTTP_PROXY"
    log "  HTTPS_PROXY: $HTTPS_PROXY"
    log "  NO_PROXY: $NO_PROXY"
}

# Function to validate configuration
validate_configuration() {
    log "Validating configuration..."
    
    # Check required environment variables
    local required_vars=("DATABASE_URL" "JWT_SECRET" "BASE_URL")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "ERROR: Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Validate BASE_URL is an onion address
    if [[ ! "$BASE_URL" =~ \.onion$ ]]; then
        log "WARNING: BASE_URL does not appear to be an onion address: $BASE_URL"
    fi
    
    log "Configuration validation passed"
    return 0
}

# Function to run database migrations
run_migrations() {
    log "Running database migrations..."
    if ./fider migrate; then
        log "Database migrations completed successfully"
        return 0
    else
        log "ERROR: Database migrations failed"
        return 1
    fi
}

# Function to display startup information
display_startup_info() {
    log "=== Fider Tor Hidden Service ==="
    log "Base URL: $BASE_URL"
    log "Environment: ${GO_ENV:-production}"
    log "Port: ${PORT:-3000}"
    log "Host Mode: ${HOST_MODE:-single}"
    log "Tor Proxy: ${HTTP_PROXY}"
    log "================================"
}

# Function to handle graceful shutdown
cleanup() {
    log "Received shutdown signal, cleaning up..."
    # Add any cleanup tasks here
    exit 0
}

# Main execution function
main() {
    log "Starting Fider with Tor integration..."
    
    # Setup signal handlers
    trap cleanup SIGTERM SIGINT
    
    # Validate configuration
    if ! validate_configuration; then
        exit 1
    fi
    
    # Setup Tor environment
    setup_tor_environment
    
    # Wait for dependencies
    if ! wait_for_tor; then
        exit 1
    fi
    
    # Display startup information
    display_startup_info
    
    # Handle different commands
    case "$1" in
        "migrate")
            log "Running migrations only..."
            run_migrations
            ;;
        "ping")
            log "Running health check..."
            exec ./fider ping
            ;;
        "./fider"|"fider"|"")
            log "Starting Fider application..."
            
            # Run migrations first
            if ! run_migrations; then
                exit 1
            fi
            
            # Start the application
            log "Starting Fider server..."
            exec ./fider
            ;;
        *)
            log "Running custom command: $*"
            exec "$@"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
