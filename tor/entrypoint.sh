#!/bin/sh
set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to generate Tor control password hash
generate_control_password() {
    if [ -z "$TOR_CONTROL_PASSWORD" ]; then
        TOR_CONTROL_PASSWORD=$(openssl rand -base64 32)
        export TOR_CONTROL_PASSWORD
        log "Generated Tor control password: $TOR_CONTROL_PASSWORD"
    fi
    
    # Generate hashed password for torrc
    tor --hash-password "$TOR_CONTROL_PASSWORD" 2>/dev/null | tail -n 1
}

# Function to wait for Tor to be ready
wait_for_tor() {
    local max_attempts=30
    local attempt=1
    
    log "Waiting for Tor to start..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl --socks5 127.0.0.1:9050 --connect-timeout 5 http://3g2upl4pq6kufc4m.onion >/dev/null 2>&1; then
            log "Tor is ready!"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: Tor not ready yet, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "ERROR: Tor failed to start within expected time"
    return 1
}

# Function to get onion address
get_onion_address() {
    local hidden_service_dir="/var/lib/tor/fider_hidden_service"
    local hostname_file="$hidden_service_dir/hostname"
    
    if [ -f "$hostname_file" ]; then
        cat "$hostname_file"
    else
        log "WARNING: Onion hostname file not found at $hostname_file"
        return 1
    fi
}

# Function to setup hidden service directory
setup_hidden_service() {
    local hidden_service_dir="/var/lib/tor/fider_hidden_service"
    
    # Create hidden service directory if it doesn't exist
    if [ ! -d "$hidden_service_dir" ]; then
        log "Creating hidden service directory: $hidden_service_dir"
        mkdir -p "$hidden_service_dir"
        chmod 700 "$hidden_service_dir"
    fi
    
    # Ensure proper ownership
    if [ "$(id -u)" = "0" ]; then
        chown -R tor:tor "$hidden_service_dir"
    fi
}

# Function to validate Tor configuration
validate_config() {
    log "Validating Tor configuration..."
    if tor --verify-config -f /etc/tor/torrc; then
        log "Tor configuration is valid"
        return 0
    else
        log "ERROR: Invalid Tor configuration"
        return 1
    fi
}

# Main execution
main() {
    log "Starting Tor hidden service setup..."
    
    # Validate configuration first
    if ! validate_config; then
        exit 1
    fi
    
    # Setup hidden service directory
    setup_hidden_service
    
    # If we're running as root, switch to tor user
    if [ "$(id -u)" = "0" ]; then
        log "Running as root, switching to tor user..."
        exec su-exec tor "$0" "$@"
    fi
    
    # Start Tor in background if we need to wait for it
    if [ "$1" = "tor" ]; then
        log "Starting Tor daemon..."
        exec "$@"
    else
        # For other commands, start Tor in background and run the command
        log "Starting Tor in background..."
        tor -f /etc/tor/torrc &
        TOR_PID=$!
        
        # Wait for Tor to be ready
        if wait_for_tor; then
            # Display onion address
            ONION_ADDRESS=$(get_onion_address)
            if [ -n "$ONION_ADDRESS" ]; then
                log "Onion address: $ONION_ADDRESS"
                echo "$ONION_ADDRESS" > /var/lib/tor/onion_address
            fi
        fi
        
        # Execute the requested command
        exec "$@"
    fi
}

# Handle signals gracefully
trap 'log "Received signal, shutting down..."; kill $TOR_PID 2>/dev/null || true; exit 0' TERM INT

# Run main function
main "$@"
