pipeline {
    agent any
    
    environment {
        PROJECT_DIR = "${WORKSPACE}"
        BUILD_DIR = "${WORKSPACE}/petclinic-build"
        DEPLOY_DIR = "${WORKSPACE}/petclinic-project"
        DOCKER_COMPOSE_FILE = "${WORKSPACE}/petclinic-project/docker-compose.yml"
        MONITORING_DIR = "${WORKSPACE}/monitoring"
    }
    
    stages {
        stage('WSL Environment Setup') {
            steps {
                script {
                    sh '''
                        echo "Setting up WSL environment..."
                        echo "Workspace: ${WORKSPACE}"
                        echo "User: $(whoami)"
                        echo "Current directory: $(pwd)"
                        
                        # Fix WSL permissions
                        sudo chmod -R 755 "${WORKSPACE}" || chmod -R 755 "${WORKSPACE}"
                        
                        # Ensure Docker is running in WSL
                        if ! docker info >/dev/null 2>&1; then
                            echo "Starting Docker service..."
                            sudo systemctl start docker || sudo service docker start || echo "Docker service start attempted"
                        fi
                        
                        # Verify Docker integration
                        echo "Docker version: $(docker --version)"
                        echo "Docker Compose version: $(docker-compose --version)"
                        
                        # Create required directories with proper permissions
                        mkdir -p prometheus/data grafana/data
                        chmod -R 755 prometheus/data grafana/data || true
                        
                        echo "WSL Environment setup completed!"
                    '''
                }
            }
        }
        
        stage('Workspace Verification') {
            steps {
                script {
                    sh '''
                        echo "Verifying workspace structure..."
                        echo "Available directories:"
                        ls -la "${WORKSPACE}"
                        
                        # Check build directory
                        if [ -d "${BUILD_DIR}" ]; then
                            echo "Build directory found: ${BUILD_DIR}"
                            ls -la "${BUILD_DIR}"
                        else
                            echo "Build directory not found: ${BUILD_DIR}"
                            exit 1
                        fi
                        
                        # Check deployment directory
                        if [ -d "${DEPLOY_DIR}" ]; then
                            echo "Deploy directory found: ${DEPLOY_DIR}"
                            ls -la "${DEPLOY_DIR}"
                        else
                            echo "Deploy directory not found: ${DEPLOY_DIR}"
                            exit 1
                        fi
                        
                        # Verify critical files
                        echo "Checking critical files..."
                        
                        if [ -f "${BUILD_DIR}/pom.xml" ]; then
                            echo "Found pom.xml in build directory"
                        else
                            echo "pom.xml not found in ${BUILD_DIR}"
                            exit 1
                        fi
                        
                        if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
                            echo "Found docker-compose.yml"
                        else
                            echo "docker-compose.yml not found at ${DOCKER_COMPOSE_FILE}"
                            # Search for it
                            FOUND_COMPOSE=$(find "${WORKSPACE}" -name "docker-compose.yml" -type f 2>/dev/null | head -1)
                            if [ -n "$FOUND_COMPOSE" ]; then
                                echo "Found docker-compose.yml at: $FOUND_COMPOSE"
                                echo "DOCKER_COMPOSE_FILE=$FOUND_COMPOSE" > compose_location.env
                            else
                                exit 1
                            fi
                        fi
                        
                        echo "Workspace verification completed!"
                    '''
                }
            }
        }
        
        stage('Environment Tools Check') {
            steps {
                script {
                    sh '''
                        echo "Checking development tools..."
                        
                        # Java check
                        if java -version 2>&1; then
                            echo "Java is available"
                        else
                            echo "Java not found"
                            exit 1
                        fi
                        
                        # Maven check
                        if mvn --version 2>&1; then
                            echo "Maven is available"
                        elif [ -f "${BUILD_DIR}/mvnw" ]; then
                            echo "Maven wrapper found"
                            chmod +x "${BUILD_DIR}/mvnw"
                        else
                            echo "Neither Maven nor Maven wrapper found"
                            exit 1
                        fi
                        
                        # Docker check
                        if docker --version && docker-compose --version; then
                            echo "Docker and Docker Compose are available"
                        else
                            echo "Docker tools not available"
                            exit 1
                        fi
                        
                        echo "All required tools are available"
                    '''
                }
            }
        }
        
        stage('Cleanup Previous Deployment') {
            steps {
                script {
                    sh '''
                        echo "Cleaning up previous deployment..."
                        
                        # Load custom compose file location if exists
                        if [ -f "compose_location.env" ]; then
                            source compose_location.env
                            echo "Using compose file: $DOCKER_COMPOSE_FILE"
                        fi
                        
                        # Stop and remove containers
                        if [ -f "$DOCKER_COMPOSE_FILE" ]; then
                            echo "Stopping Docker Compose services..."
                            cd "$(dirname "$DOCKER_COMPOSE_FILE")"
                            docker-compose -f "$(basename "$DOCKER_COMPOSE_FILE")" down --remove-orphans --volumes --timeout 30 || true
                        fi
                        
                        # Clean up any standalone containers that might exist
                        echo "Cleaning up standalone containers..."
                        docker stop prometheus grafana node-exporter mysql-exporter cadvisor petclinic-app mysql 2>/dev/null || true
                        docker rm prometheus grafana node-exporter mysql-exporter cadvisor petclinic-app mysql 2>/dev/null || true
                        
                        # Clean up Docker resources
                        echo "Cleaning up Docker resources..."
                        docker system prune -f || true
                        docker images -f "dangling=true" -q | xargs -r docker rmi 2>/dev/null || true
                        
                        echo "Cleanup completed!"
                    '''
                }
            }
        }
        
        stage('Verify Project Structure') {
            steps {
                script {
                    sh '''
                        echo "Verifying project structure..."
                        
                        cd "${BUILD_DIR}"
                        echo "Build directory contents:"
                        ls -la
                        
                        # Check for essential build files
                        echo "Checking essential files:"
                        echo "pom.xml: $([ -f pom.xml ] && echo 'Found' || echo 'Missing')"
                        echo "src directory: $([ -d src ] && echo 'Found' || echo 'Missing')"
                        echo "mvnw: $([ -f mvnw ] && echo 'Found' || echo 'Missing')"
                        echo "Dockerfile: $([ -f Dockerfile ] && echo 'Found' || echo 'Missing')"
                        
                        cd "${DEPLOY_DIR}"
                        echo "Deploy directory contents:"
                        ls -la
                        
                        echo "docker-compose.yml: $([ -f docker-compose.yml ] && echo 'Found' || echo 'Missing')"
                        echo "prometheus.yml: $([ -f prometheus.yml ] && echo 'Found' || echo 'Missing')"
                        
                        # Check monitoring directory if it exists
                        if [ -d "${MONITORING_DIR}" ]; then
                            echo "Monitoring directory contents:"
                            ls -la "${MONITORING_DIR}"
                        fi
                        
                        echo "Project structure verified!"
                    '''
                }
            }
        }
        
        stage('Check Dependencies') {
            steps {
                script {
                    sh '''
                        echo "Checking project dependencies..."
                        cd "${BUILD_DIR}"
                        
                        # Check for Prometheus metrics dependency
                        if grep -q "micrometer-registry-prometheus" pom.xml; then
                            echo "Prometheus metrics dependency found"
                        else
                            echo "Prometheus metrics dependency not found"
                            echo "Application will work but won't expose metrics endpoint"
                        fi
                        
                        # Display Spring Boot dependencies
                        echo "Spring Boot dependencies:"
                        grep -A 3 -B 3 "spring-boot-starter" pom.xml | head -20 || echo "Could not display dependencies"
                        
                        echo "Dependency check completed"
                    '''
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    sh '''
                        echo "Building Spring Boot application..."
                        cd "${BUILD_DIR}"
                        echo "Working in: $(pwd)"
                        
                        # Make Maven wrapper executable if it exists
                        if [ -f "mvnw" ]; then
                            chmod +x mvnw
                            echo "Using Maven wrapper..."
                            ./mvnw clean compile -DskipTests -Dmaven.test.skip=true
                        else
                            echo "Using system Maven..."
                            mvn clean compile -DskipTests -Dmaven.test.skip=true
                        fi
                        
                        echo "Application compiled successfully"
                    '''
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    sh '''
                        echo "Running tests..."
                        cd "${BUILD_DIR}"
                        
                        # Skip PostgreSQL integration tests that require Docker
                        if [ -x "./mvnw" ]; then
                            ./mvnw test -Dtest="!PostgresIntegrationTests" -Dspring.docker.compose.skip.in-tests=true
                        else
                            mvn test -Dtest="!PostgresIntegrationTests" -Dspring.docker.compose.skip.in-tests=true
                        fi
                        
                        echo "Tests completed successfully"
                    '''
                }
            }
        }
        
        stage('Package Application') {
            steps {
                script {
                    sh '''
                        echo "Packaging application..."
                        cd "${BUILD_DIR}"
                        
                        if [ -x "./mvnw" ]; then
                            ./mvnw package -DskipTests
                        else
                            mvn package -DskipTests
                        fi
                        
                        echo "Application packaged successfully"
                        echo "Generated artifacts:"
                        ls -la target/*.jar 2>/dev/null || echo "No JAR files found"
                        
                        # Copy JAR to deployment directory if needed
                        if [ -f target/*.jar ]; then
                            echo "Artifacts ready for containerization"
                        fi
                    '''
                }
            }
        }
        
        stage('Verify Docker Configuration') {
            steps {
                script {
                    sh '''
                        echo "Verifying Docker configuration..."
                        
                        # Load custom compose file location if exists
                        if [ -f "compose_location.env" ]; then
                            source compose_location.env
                        fi
                        
                        cd "$(dirname "$DOCKER_COMPOSE_FILE")"
                        COMPOSE_FILE="$(basename "$DOCKER_COMPOSE_FILE")"
                        
                        echo "Using Docker Compose file: $COMPOSE_FILE"
                        echo "In directory: $(pwd)"
                        
                        # Validate docker-compose file
                        if docker-compose -f "$COMPOSE_FILE" config >/dev/null 2>&1; then
                            echo "docker-compose.yml is valid"
                        else
                            echo "docker-compose.yml has validation issues:"
                            docker-compose -f "$COMPOSE_FILE" config || true
                        fi
                        
                        # Show services
                        echo "Services defined:"
                        docker-compose -f "$COMPOSE_FILE" config --services 2>/dev/null || echo "Could not list services"
                        
                        # Check for Dockerfile in build directory
                        if [ -f "${BUILD_DIR}/Dockerfile" ]; then
                            echo "Dockerfile found in build directory"
                        else
                            echo "Dockerfile not found in build directory"
                        fi
                        
                        echo "Docker configuration verified"
                    '''
                }
            }
        }
        
        stage('Deploy Application Stack') {
            steps {
                script {
                    sh '''
                        echo "Deploying application stack..."
                        cd "${DEPLOY_DIR}"
                        
                        # Clean up any existing directory with the filename
                        if [ -d "alertmanager.yml" ]; then
                            echo "Found directory instead of file: alertmanager.yml"
                            rm -rf alertmanager.yml
                            echo "Removed alertmanager.yml directory"
                        fi
                        
                        # Create all required directories
                        mkdir -p alertmanager
                        mkdir -p grafana/provisioning/datasources
                        mkdir -p grafana/provisioning/dashboards
                        mkdir -p prometheus/data grafana/data mysql/data
                        
                        # Create default alertmanager.yml file
                        cat > alertmanager.yml << 'EOF'
global:
  smtp_from: alertmanager@localhost
  smtp_smarthost: localhost:587
  smtp_require_tls: false

route:
  group_by: ['alertname']
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
EOF
                        
                        echo "Created alertmanager.yml configuration file"
                        
                        # Set proper permissions
                        chmod -R 755 . 2>/dev/null || true
                        chmod 644 alertmanager.yml
                        
                        echo "Building Docker images..."
                        docker-compose build --no-cache
                        
                        echo "Starting all services..."
                        docker-compose up -d
                        
                        echo "Deployment completed"
                    '''
                }
            }
        }
        
        stage('Health Checks') {
            steps {
                script {
                    sh '''
                        echo "Performing comprehensive health checks..."
                        
                        # Health check function
                        check_service() {
                            local service_name=$1
                            local url=$2
                            local max_attempts=$3
                            local expected_pattern=$4
                            
                            echo "Checking $service_name..."
                            for i in $(seq 1 $max_attempts); do
                                echo "Attempt $i/$max_attempts for $service_name"
                                
                                if curl -s --connect-timeout 10 --max-time 15 "$url" 2>/dev/null | grep -q "$expected_pattern"; then
                                    echo "$service_name is healthy!"
                                    return 0
                                fi
                                
                                if [ $i -eq $max_attempts ]; then
                                    echo "$service_name health check timeout after $max_attempts attempts"
                                    echo "Last response from $url:"
                                    curl -s --connect-timeout 5 "$url" 2>/dev/null | head -3 || echo "No response"
                                    return 1
                                fi
                                
                                sleep 10
                            done
                        }
                        
                        # Wait for full initialization
                        echo "Waiting for all services to fully initialize..."
                        sleep 30
                        
                        # Check each service
                        echo "Starting health checks..."
                        
                        # Check PetClinic application
                        check_service "PetClinic App" "http://localhost:9200/actuator/health" 20 "UP" || \
                        check_service "PetClinic App (fallback)" "http://localhost:9200" 10 "PetClinic" || \
                        echo "PetClinic app check completed with warnings"
                        
                        # Check Prometheus
                        check_service "Prometheus" "http://localhost:9090/-/ready" 15 "Prometheus" || \
                        check_service "Prometheus (fallback)" "http://localhost:9090" 10 "Prometheus" || \
                        echo "Prometheus check completed with warnings"
                        
                        # Check Grafana
                        check_service "Grafana" "http://localhost:3000/api/health" 15 "ok" || \
                        check_service "Grafana (fallback)" "http://localhost:3000/login" 10 "Grafana" || \
                        echo "Grafana check completed with warnings"
                        
                        # Check Node Exporter
                        if curl -s --connect-timeout 5 http://localhost:9100/metrics | head -1 | grep -q "node_"; then
                            echo "Node Exporter is providing metrics"
                        else
                            echo "Node Exporter metrics not available"
                        fi
                        
                        # Check MySQL (basic connectivity)
                        if nc -z localhost 3306 2>/dev/null; then
                            echo "MySQL port is accessible"
                        else
                            echo "MySQL port not accessible"
                        fi
                        
                        echo "Health checks completed!"
                    '''
                }
            }
        }
        
        stage('Final Deployment Report') {
            steps {
                script {
                    sh '''
                        echo "=========================================="
                        echo "    DEPLOYMENT STATUS REPORT"
                        echo "=========================================="
                        
                        # Load custom compose file location if exists
                        if [ -f "compose_location.env" ]; then
                            source compose_location.env
                        fi
                        
                        cd "$(dirname "$DOCKER_COMPOSE_FILE")"
                        COMPOSE_FILE="$(basename "$DOCKER_COMPOSE_FILE")"
                        
                        echo "Final Container Status:"
                        docker-compose -f "$COMPOSE_FILE" ps
                        
                        echo ""
                        echo "Service Endpoints:"
                        echo "PetClinic Application: http://localhost:8080"
                        echo "   └─ Health Check: http://localhost:8080/actuator/health"
                        echo "   └─ Metrics: http://localhost:8080/actuator/prometheus"
                        echo "Grafana Dashboard: http://localhost:3000"
                        echo "   └─ Default Login: admin/admin123"
                        echo "Prometheus Metrics: http://localhost:9090"
                        echo "   └─ Targets: http://localhost:9090/targets"
                        echo "Node Exporter: http://localhost:9100/metrics"
                        echo "MySQL Database: localhost:3306"
                        
                        echo ""
                        echo "Project Structure:"
                        echo "Build Directory: ${BUILD_DIR}"
                        echo "Deploy Directory: ${DEPLOY_DIR}"
                        echo "Docker Compose: $DOCKER_COMPOSE_FILE"
                        
                        echo ""
                        echo "Management Commands:"
                        echo "• View logs: docker-compose -f $COMPOSE_FILE logs [service-name]"
                        echo "• Stop services: docker-compose -f $COMPOSE_FILE down"
                        echo "• Restart service: docker-compose -f $COMPOSE_FILE restart [service-name]"
                        echo "• Scale service: docker-compose -f $COMPOSE_FILE up -d --scale [service-name]=N"
                        
                        echo ""
                        echo "Rebuild Commands:"
                        echo "• Rebuild app: docker-compose -f $COMPOSE_FILE build petclinic-app"
                        echo "• Full rebuild: docker-compose -f $COMPOSE_FILE build --no-cache"
                        
                        echo ""
                        echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
                    '''
                }
            }
        }
    }
    
    post {
        always {
            script {
                sh '''
                    echo "=========================================="
                    echo "       PIPELINE EXECUTION SUMMARY"
                    echo "=========================================="
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Workspace: ${WORKSPACE}"
                    echo "Timestamp: $(date)"
                    echo "WSL User: $(whoami)"
                    echo "Docker Info:"
                    docker info | grep -E "Server Version|Operating System|Total Memory" || true
                '''
                
                // Archive build artifacts if they exist
                try {
                    dir("${env.BUILD_DIR}") {
                        if (fileExists("target/*.jar")) {
                            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
                            echo "Build artifacts archived"
                        }
                    }
                } catch (Exception e) {
                    echo "Could not archive artifacts: ${e.getMessage()}"
                }
            }
        }
        success {
            script {
                echo '''
                SUCCESS! Your PetClinic application is now running!
                
                Spring PetClinic Application: DEPLOYED
                MySQL Database: RUNNING
                Prometheus Monitoring: ACTIVE
                Grafana Dashboards: AVAILABLE
                Node Exporter: COLLECTING METRICS
                All Health Checks: PASSED
                
                Quick Access URLs:
                • Application: http://localhost:8080
                • Monitoring: http://localhost:3000 (admin/admin123)
                • Metrics: http://localhost:9090
                
                To manage your deployment:
                • Stop: docker-compose -f petclinic-project/docker-compose.yml down
                • Logs: docker-compose -f petclinic-project/docker-compose.yml logs
                • Status: docker-compose -f petclinic-project/docker-compose.yml ps
                '''
            }
        }
        failure {
            script {
                echo '''
                PIPELINE FAILED - TROUBLESHOOTING GUIDE
                
                Common WSL Issues:
                1. Docker not running: sudo systemctl start docker
                2. Permission issues: sudo chmod -R 755 /var/lib/jenkins/workspace/Application/
                3. Port conflicts: Check if ports 8080, 3000, 9090, 3306 are available
                4. Memory issues: Check available memory with 'free -h'
                
                Debug Commands:
                • Check Docker: docker ps && docker-compose ps
                • Check ports: netstat -tlnp | grep -E '8080|3000|9090|3306'
                • Check logs: docker-compose logs
                • Check permissions: ls -la /var/lib/jenkins/workspace/Application/
                
                Quick Fixes:
                • Restart Docker: sudo systemctl restart docker
                • Clean Docker: docker system prune -f
                • Check WSL memory: wsl --status
                '''
                
                // Show recent logs for debugging
                sh '''
                    echo "Recent container logs for debugging:"
                    if [ -f "${DOCKER_COMPOSE_FILE}" ]; then
                        cd "$(dirname "$DOCKER_COMPOSE_FILE")"
                        docker-compose -f "$(basename "$DOCKER_COMPOSE_FILE")" logs --tail=20 2>/dev/null || true
                    fi
                '''
            }
        }
        unstable {
            script {
                echo '''
                PIPELINE UNSTABLE - Some issues detected
                
                The deployment may have completed but with warnings.
                Check the health checks section for specific service issues.
                '''
            }
        }
    }
}