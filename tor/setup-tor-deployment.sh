#!/bin/bash

# Fider Tor Hidden Service Setup Script
# This script helps set up Fider as a Tor hidden service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to generate secure random string
generate_secret() {
    local length=${1:-64}
    if command_exists openssl; then
        openssl rand -base64 $length | tr -d '\n'
    elif command_exists head && [ -f /dev/urandom ]; then
        head -c $length /dev/urandom | base64 | tr -d '\n'
    else
        print_error "Cannot generate secure random string. Please install openssl."
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    local missing_deps=()
    
    if ! command_exists docker; then
        missing_deps+=("docker")
    fi
    
    if ! command_exists docker-compose; then
        missing_deps+=("docker-compose")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_error "Please install the missing dependencies and try again."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to setup environment file
setup_environment() {
    print_status "Setting up environment configuration..."
    
    local env_file=".env.tor"
    
    if [ -f "$env_file" ]; then
        print_warning "Environment file $env_file already exists."
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Keeping existing environment file."
            return 0
        fi
    fi
    
    print_status "Generating secure secrets..."
    
    # Generate JWT secret
    local jwt_secret
    jwt_secret=$(generate_secret 64)
    
    # Generate database password
    local db_password
    db_password=$(generate_secret 32)
    
    # Create environment file from template
    cp .env.tor.example "$env_file"
    
    # Replace placeholders
    sed -i.bak \
        -e "s/JWT_SECRET=CHANGE_THIS_TO_A_STRONG_RANDOM_SECRET_AT_LEAST_64_CHARACTERS_LONG/JWT_SECRET=$jwt_secret/" \
        -e "s/POSTGRES_PASSWORD=CHANGE_THIS_TO_A_STRONG_DATABASE_PASSWORD/POSTGRES_PASSWORD=$db_password/" \
        "$env_file"
    
    # Remove backup file
    rm -f "$env_file.bak"
    
    print_success "Environment file created: $env_file"
    print_warning "Please review and customize the settings in $env_file before starting the service."
}

# Function to build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build Tor image
    print_status "Building Tor image..."
    docker build -t fider-tor:latest ./tor/
    
    # Build Fider image
    print_status "Building Fider image..."
    docker build -f Dockerfile.tor -t fider-app-tor:latest .
    
    print_success "Docker images built successfully"
}

# Function to start services
start_services() {
    print_status "Starting Tor hidden service..."
    
    # Start services
    docker-compose -f docker-compose.tor.yml --env-file .env.tor up -d
    
    print_success "Services started successfully"
    
    # Wait for services to be ready
    print_status "Waiting for services to initialize..."
    sleep 10
    
    # Get onion address
    get_onion_address
}

# Function to get onion address
get_onion_address() {
    print_status "Retrieving onion address..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local onion_address
        onion_address=$(docker exec fider_tor cat /var/lib/tor/fider_hidden_service/hostname 2>/dev/null || true)
        
        if [ -n "$onion_address" ]; then
            print_success "Your Fider hidden service is available at:"
            echo -e "${GREEN}http://$onion_address${NC}"
            
            # Update environment file with onion address
            if [ -f ".env.tor" ]; then
                sed -i.bak \
                    -e "s/ONION_ADDRESS=your-generated-address.onion/ONION_ADDRESS=$onion_address/" \
                    -e "s|BASE_URL=http://your-generated-address.onion|BASE_URL=http://$onion_address|" \
                    .env.tor
                rm -f .env.tor.bak
                print_status "Environment file updated with onion address"
            fi
            
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts: Waiting for onion address generation..."
        sleep 5
        attempt=$((attempt + 1))
    done
    
    print_error "Failed to retrieve onion address. Check the logs with: docker-compose -f docker-compose.tor.yml logs tor"
    return 1
}

# Function to show status
show_status() {
    print_status "Service status:"
    docker-compose -f docker-compose.tor.yml ps
    
    echo
    print_status "To view logs:"
    echo "  docker-compose -f docker-compose.tor.yml logs -f"
    
    echo
    print_status "To stop services:"
    echo "  docker-compose -f docker-compose.tor.yml down"
}

# Function to show help
show_help() {
    echo "Fider Tor Hidden Service Setup Script"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  setup     - Complete setup (check deps, setup env, build, start)"
    echo "  env       - Setup environment file only"
    echo "  build     - Build Docker images only"
    echo "  start     - Start services only"
    echo "  status    - Show service status"
    echo "  address   - Show onion address"
    echo "  stop      - Stop services"
    echo "  help      - Show this help message"
    echo
}

# Function to stop services
stop_services() {
    print_status "Stopping services..."
    docker-compose -f docker-compose.tor.yml down
    print_success "Services stopped"
}

# Main function
main() {
    local command=${1:-setup}
    
    case $command in
        "setup")
            print_status "Starting complete Fider Tor hidden service setup..."
            check_prerequisites
            setup_environment
            build_images
            start_services
            show_status
            ;;
        "env")
            setup_environment
            ;;
        "build")
            check_prerequisites
            build_images
            ;;
        "start")
            check_prerequisites
            start_services
            show_status
            ;;
        "status")
            show_status
            ;;
        "address")
            get_onion_address
            ;;
        "stop")
            stop_services
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
