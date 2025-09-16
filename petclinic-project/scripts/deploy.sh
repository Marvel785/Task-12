#!/bin/bash

# Container Monitoring Deployment Script
# Deploys PetClinic with full monitoring stack

set -e  # Exit on any error

echo "🚀 Starting PetClinic Container Monitoring Deployment"
echo "=================================================="

# Configuration
PROJECT_DIR="$(pwd)"
COMPOSE_FILE="docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed!"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        error "Docker Compose is not installed!"
        exit 1
    fi
    
    # Check Ansible (optional)
    if command -v ansible-playbook >/dev/null 2>&1; then
        info "Ansible found - will use for configuration"
        ANSIBLE_AVAILABLE=true
    else
        warn "Ansible not found - using basic configuration"
        ANSIBLE_AVAILABLE=false
    fi
    
    log "✅ Prerequisites check completed"
}

# Cleanup previous deployment
cleanup_previous() {
    log "Cleaning up previous deployment..."
    
    # Stop and remove containers
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Clean up Docker system
    docker system prune -f >/dev/null 2>&1 || true
    
    log "✅ Cleanup completed"
}

# Setup directory structure
setup_directories() {
    log "Setting up directory structure..."
    
    mkdir -p {monitoring,prometheus/data,grafana/{data,provisioning/{datasources,dashboards}},dashboards,scripts}
    
    # Set permissions for monitoring tools
    sudo chown -R 472:472 grafana/data 2>/dev/null || warn "Could not set Grafana permissions"
    sudo chown -R 65534:65534 prometheus/data 2>/dev/null || warn "Could not set Prometheus permissions"
    
    log "✅ Directory structure created"
}

# Run Ansible configuration if available
run_ansible_config() {
    if [ "$ANSIBLE_AVAILABLE" = true ] && [ -f "ansible/setup-monitoring.yml" ]; then
        log "Running Ansible configuration..."
        
        cd ansible
        ansible-playbook -i inventory.yml setup-monitoring.yml --connection=local
        cd ..
        
        log "✅ Ansible configuration completed"
    else
        warn "Skipping Ansible configuration"
        
        # Create basic prometheus config if not exists
        if [ ! -f "prometheus.yml" ]; then
            info "Creating basic Prometheus configuration..."
            cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'petclinic-app'
    static_configs:
      - targets: ['petclinic-app:8080']
    metrics_path: '/actuator/prometheus'
    scrape_interval: 15s

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
    scrape_interval: 30s

  - job_name: 'docker-containers'
    static_configs:
      - targets: ['cadvisor:8080']
    scrape_interval: 30s
EOF
        fi
    fi
}

# Verify configuration files
verify_files() {
    log "Verifying configuration files..."
    
    required_files=(
        "docker-compose.yml"
        "Dockerfile"
        "prometheus.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            error "Required file missing: $file"
            exit 1
        fi
    done
    
    log "✅ All required files present"
}

# Build and deploy services
deploy_services() {
    log "Building and deploying services..."
    
    # Build images
    info "Building Docker images..."
    docker-compose build --no-cache
    
    # Start services
    info "Starting services..."
    docker-compose up -d
    
    log "✅ Services deployment initiated"
}

# Health checks
run_health_checks() {
    log "Running health checks..."
    
    # Wait for services to start
    info "Waiting for services to initialize..."
    sleep 30
    
    # Check MySQL
    info "Checking MySQL..."
    for i in {1..20}; do
        if docker-compose exec -T mysql mysqladmin ping -h localhost -u root -prootpassword --silent 2>/dev/null; then
            log "✅ MySQL is healthy"
            break
        fi
        if [ $i -eq 20 ]; then
            error "MySQL health check failed"
            return 1
        fi
        sleep 3
    done
    
    # Check PetClinic App
    info "Checking PetClinic application..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/actuator/health | grep -q "UP" 2>/dev/null; then
            log "✅ PetClinic application is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            error "PetClinic health check failed"
            return 1
        fi
        sleep 5
    done
    
    # Check Prometheus
    info "Checking Prometheus..."
    for i in {1..20}; do
        if curl -s http://localhost:9090/-/ready | grep -q "Prometheus is Ready" 2>/dev/null; then
            log "✅ Prometheus is ready"
            break
        fi
        if [ $i -eq 20 ]; then
            warn "Prometheus health check failed"
        fi
        sleep 3
    done
    
    # Check Grafana
    info "Checking Grafana..."
    for i in {1..20}; do
        if curl -s http://localhost:3000/api/health | grep -q "ok" 2>/dev/null; then
            log "✅ Grafana is healthy"
            break
        fi
        if [ $i -eq 20 ]; then
            warn "Grafana health check failed"
        fi
        sleep 3
    done
    
    log "✅ Health checks completed"
}

# Display service information
show_services() {
    echo ""
    echo "🎉 Deployment Completed Successfully!"
    echo "====================================="
    echo ""
    echo "📊 Services available at:"
    echo "• PetClinic Application: http://localhost:9200"
    echo "  - Health: http://localhost:9200/actuator/health"
    echo "  - Metrics: http://localhost:9200/actuator/prometheus"
    echo ""
    echo "• Grafana Dashboard: http://localhost:3000"
    echo "  - Username: admin"
    echo "  - Password: admin123"
    echo ""
    echo "• Prometheus: http://localhost:9090"
    echo "  - Targets: http://localhost:9090/targets"
    echo ""
    echo "• MySQL Database: localhost:3306"
    echo "  - Database: petclinic"
    echo "  - Username: petclinic / Password: petclinic"
    echo ""
    echo "• Container Metrics: http://localhost:8081 (cAdvisor)"
    echo "• MySQL Metrics: http://localhost:9104 (MySQL Exporter)"
    echo ""
    echo "🔧 Management Commands:"
    echo "• View logs: docker-compose logs -f [service-name]"
    echo "• Stop services: docker-compose down"
    echo "• Restart services: docker-compose restart"
    echo ""
}

# Main deployment function
main() {
    echo ""
    log "Starting deployment process..."
    
    check_prerequisites
    cleanup_previous
    setup_directories
    run_ansible_config
    verify_files
    deploy_services
    run_health_checks
    show_services
    
    log "🚀 Container monitoring deployment completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted!"; exit 1' INT TERM

# Run main function
main "$@"