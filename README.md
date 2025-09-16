# Jenkins Pipeline README - PetClinic Application Deployment

## Overview
This Jenkins pipeline automates the complete deployment of a Spring Boot PetClinic application with comprehensive monitoring stack including Prometheus, Grafana, and MySQL database in a WSL (Windows Subsystem for Linux) environment.

## Prerequisites

### System Requirements
- WSL 2 with Ubuntu/Debian distribution
- Docker Desktop with WSL 2 integration enabled
- Jenkins installed and running in WSL
- Java 17 or higher
- Maven 3.8+ (or Maven wrapper included in project)

### Directory Structure Required
```
/var/lib/jenkins/workspace/Application/
├── petclinic-build/          # Spring Boot source code
│   ├── pom.xml
│   ├── src/
│   ├── mvnw (optional)
│   └── Dockerfile
└── petclinic-project/        # Deployment configuration
    ├── docker-compose.yml
    ├── prometheus.yml
    └── other config files
```

## Pipeline Stages Detailed Explanation

### Stage 1: WSL Environment Setup
**Purpose**: Initialize the WSL environment and ensure Docker is running

**What it does**:
- Displays current workspace information
- Fixes file permissions issues common in WSL
- Starts Docker service if not running
- Verifies Docker and Docker Compose installations
- Creates necessary directories for Prometheus and Grafana data
- Sets proper permissions on directories

**Expected Output**:
```
Setting up WSL environment...
Workspace: /var/lib/jenkins/workspace/Application
User: jenkins
Docker version: Docker version 24.x.x
Docker Compose version: docker-compose version 1.x.x
WSL Environment setup completed!
```

### Stage 2: Workspace Verification
**Purpose**: Verify the required directory structure and files exist

**What it does**:
- Checks for build directory (`petclinic-build`)
- Checks for deployment directory (`petclinic-project`)
- Verifies critical files exist:
  - `pom.xml` in build directory
  - `docker-compose.yml` in deployment directory
- If `docker-compose.yml` not found in expected location, searches workspace
- Creates environment file with correct compose location if needed

**Failure Points**:
- Missing build or deployment directories
- Missing `pom.xml` or `docker-compose.yml` files

### Stage 3: Environment Tools Check
**Purpose**: Verify all required development tools are available

**What it does**:
- Checks Java installation and version
- Verifies Maven availability (system or wrapper)
- Makes Maven wrapper executable if present
- Confirms Docker and Docker Compose are functional

**Tools Verified**:
- Java Runtime Environment
- Maven or Maven Wrapper (mvnw)
- Docker Engine
- Docker Compose

### Stage 4: Cleanup Previous Deployment
**Purpose**: Clean slate for new deployment by removing previous containers and resources

**What it does**:
- Loads custom compose file location if exists
- Stops all Docker Compose services gracefully
- Removes containers, volumes, and orphaned resources
- Cleans up standalone containers by name
- Prunes Docker system to free space
- Removes dangling Docker images

**Services Cleaned**:
- prometheus, grafana, node-exporter
- mysql-exporter, cadvisor
- petclinic-app, mysql

### Stage 5: Verify Project Structure
**Purpose**: Detailed inspection of project files and structure

**What it does**:
- Lists contents of build directory
- Checks for essential build files:
  - `pom.xml` (Maven configuration)
  - `src/` directory (source code)
  - `mvnw` (Maven wrapper)
  - `Dockerfile` (container configuration)
- Lists contents of deployment directory
- Verifies deployment configuration files:
  - `docker-compose.yml`
  - `prometheus.yml`
- Checks monitoring directory if present

### Stage 6: Check Dependencies
**Purpose**: Analyze Maven dependencies, especially monitoring-related ones

**What it does**:
- Searches `pom.xml` for Prometheus metrics dependency (`micrometer-registry-prometheus`)
- Displays Spring Boot starter dependencies
- Warns if metrics endpoint won't be available

**Important Note**: If Prometheus metrics dependency is missing, the application will still work but won't expose the `/actuator/prometheus` endpoint.

### Stage 7: Build Application
**Purpose**: Compile the Spring Boot application

**What it does**:
- Changes to build directory
- Uses Maven wrapper if available, otherwise system Maven
- Runs `clean compile` with tests skipped for faster compilation
- Prepares application for packaging

**Maven Commands Used**:
```bash
./mvnw clean compile -DskipTests -Dmaven.test.skip=true
# OR
mvn clean compile -DskipTests -Dmaven.test.skip=true
```

### Stage 8: Run Tests
**Purpose**: Execute unit and integration tests

**What it does**:
- Runs test suite while excluding problematic tests
- Skips PostgreSQL integration tests that require Docker
- Skips Docker Compose tests during test phase
- Uses appropriate Maven command (wrapper or system)

**Test Exclusions**:
- `PostgresIntegrationTests` (requires separate Docker setup)
- Spring Boot Docker Compose integration tests

### Stage 9: Package Application
**Purpose**: Create deployable JAR artifact

**What it does**:
- Packages application into executable JAR file
- Skips tests during packaging for speed
- Lists generated artifacts
- Confirms artifacts are ready for containerization

**Generated Artifacts**:
- `target/*.jar` - Executable Spring Boot JAR file

### Stage 10: Verify Docker Configuration
**Purpose**: Validate Docker Compose configuration before deployment

**What it does**:
- Loads custom compose file location if needed
- Validates `docker-compose.yml` syntax
- Lists all defined services
- Checks for Dockerfile in build directory
- Reports any configuration issues

**Services Typically Defined**:
- petclinic-app (Spring Boot application)
- mysql (database)
- prometheus (metrics collection)
- grafana (monitoring dashboard)
- node-exporter (system metrics)

### Stage 11: Deploy Application Stack
**Purpose**: Deploy complete application stack with monitoring

**What it does**:
- Handles alertmanager configuration issues
- Creates required directories for all services:
  - `alertmanager/`
  - `grafana/provisioning/datasources`
  - `grafana/provisioning/dashboards`
  - `prometheus/data`, `grafana/data`, `mysql/data`
- Creates default `alertmanager.yml` configuration
- Sets proper permissions on all directories
- Builds Docker images from scratch (no cache)
- Starts all services in detached mode

**Default Alertmanager Configuration**:
```yaml
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
```

### Stage 12: Health Checks
**Purpose**: Comprehensive verification that all services are running correctly

**What it does**:
- Defines reusable health check function
- Waits 30 seconds for service initialization
- Checks each service with multiple fallback attempts:

**Services Checked**:
1. **PetClinic Application**:
   - Primary: `http://localhost:8080/actuator/health` (expects "UP")
   - Fallback: `http://localhost:8080` (expects "PetClinic")
   - Max attempts: 20

2. **Prometheus**:
   - Primary: `http://localhost:9090/-/ready` (expects "Prometheus")
   - Fallback: `http://localhost:9090` (expects "Prometheus")
   - Max attempts: 15

3. **Grafana**:
   - Primary: `http://localhost:3000/api/health` (expects "ok")
   - Fallback: `http://localhost:3000/login` (expects "Grafana")
   - Max attempts: 15

4. **Node Exporter**:
   - Checks: `http://localhost:9100/metrics` (expects node metrics)

5. **MySQL**:
   - Basic connectivity check on port 3306

**Health Check Parameters**:
- Connection timeout: 10 seconds
- Max time per request: 15 seconds
- Retry interval: 10 seconds between attempts

### Stage 13: Final Deployment Report
**Purpose**: Provide comprehensive deployment status and management information

**What it does**:
- Displays final container status using `docker-compose ps`
- Lists all service endpoints with access URLs
- Shows project directory structure
- Provides management commands for ongoing operations
- Gives rebuild commands for maintenance

**Service Endpoints Provided**:
- **PetClinic Application**: `http://localhost:8080`
  - Health Check: `http://localhost:8080/actuator/health`
  - Metrics: `http://localhost:8080/actuator/prometheus`
- **Grafana Dashboard**: `http://localhost:3000`
  - Default Login: admin/admin123
- **Prometheus Metrics**: `http://localhost:9090`
  - Targets: `http://localhost:9090/targets`
- **Node Exporter**: `http://localhost:9100/metrics`
- **MySQL Database**: `localhost:3306`

**Management Commands**:
```bash
# View logs
docker-compose -f docker-compose.yml logs [service-name]

# Stop services
docker-compose -f docker-compose.yml down

# Restart service
docker-compose -f docker-compose.yml restart [service-name]

# Scale service
docker-compose -f docker-compose.yml up -d --scale [service-name]=N
```

**Rebuild Commands**:
```bash
# Rebuild specific service
docker-compose -f docker-compose.yml build petclinic-app

# Full rebuild all services
docker-compose -f docker-compose.yml build --no-cache
```

## Post-Build Actions

### Always Executed
**Purpose**: Provide execution summary and archive artifacts

**What it does**:
- Shows pipeline execution summary
- Displays build number, workspace, timestamp
- Shows current WSL user and Docker information
- Archives JAR artifacts if build was successful
- Captures build fingerprint for tracking

### Success Actions
**Purpose**: Confirmation message and quick access information

**Displays**:
- Success confirmation for all components
- Quick access URLs for immediate use
- Basic management commands
- Service status confirmation

### Failure Actions
**Purpose**: Troubleshooting guidance when pipeline fails

**Provides**:
- Common WSL-specific issues and solutions
- Debug commands for investigating problems
- Quick fix suggestions
- Recent container logs for analysis

**Common Issues Addressed**:
1. Docker service not running
2. Permission issues in WSL
3. Port conflicts (8080, 3000, 9090, 3306)
4. Memory constraints

**Debug Commands Provided**:
```bash
# Check Docker status
docker ps && docker-compose ps

# Check port availability
netstat -tlnp | grep -E '8080|3000|9090|3306'

# View container logs
docker-compose logs

# Check workspace permissions
ls -la /var/lib/jenkins/workspace/Application/
```

**Quick Fix Commands**:
```bash
# Restart Docker
sudo systemctl restart docker

# Clean Docker resources
docker system prune -f

# Check WSL status
wsl --status
```

### Unstable Actions
**Purpose**: Handle partial success scenarios

**What it does**:
- Warns about potential issues detected
- Directs user to check health checks section
- Provides guidance for partial deployments

## Environment Variables

The pipeline uses several environment variables for flexibility:

| Variable | Purpose | Default Value |
|----------|---------|---------------|
| `PROJECT_DIR` | Main workspace directory | `${WORKSPACE}` |
| `BUILD_DIR` | Source code location | `${WORKSPACE}/petclinic-build` |
| `DEPLOY_DIR` | Deployment configs location | `${WORKSPACE}/petclinic-project` |
| `DOCKER_COMPOSE_FILE` | Docker Compose file path | `${WORKSPACE}/petclinic-project/docker-compose.yml` |
| `MONITORING_DIR` | Monitoring configs location | `${WORKSPACE}/monitoring` |

## Expected Execution Time

| Stage | Typical Duration | Notes |
|-------|------------------|-------|
| WSL Environment Setup | 30-60 seconds | Depends on Docker startup |
| Workspace Verification | 5-10 seconds | File system checks |
| Environment Tools Check | 10-20 seconds | Tool availability checks |
| Cleanup Previous Deployment | 60-120 seconds | Depends on existing containers |
| Verify Project Structure | 5-10 seconds | Directory and file checks |
| Check Dependencies | 10-20 seconds | Maven dependency analysis |
| Build Application | 60-180 seconds | Depends on project size |
| Run Tests | 30-120 seconds | Depends on test suite |
| Package Application | 30-90 seconds | JAR creation time |
| Verify Docker Configuration | 10-20 seconds | Compose file validation |
| Deploy Application Stack | 180-300 seconds | Image building and startup |
| Health Checks | 120-240 seconds | Service startup verification |
| Final Deployment Report | 10-20 seconds | Status reporting |

**Total Expected Time**: 8-15 minutes for complete deployment

## Ports Used

| Service | Port | Purpose |
|---------|------|---------|
| PetClinic App | 8080 | Web application |
| MySQL | 3306 | Database |
| Grafana | 3000 | Monitoring dashboard |
| Prometheus | 9090 | Metrics collection |
| Node Exporter | 9100 | System metrics |
| AlertManager | 9093 | Alert management (if configured) |

## Troubleshooting Common Issues

### Issue 1: Docker Service Not Started
**Symptoms**: "Cannot connect to the Docker daemon"
**Solution**:
```bash
sudo systemctl start docker
# OR
sudo service docker start
```

### Issue 2: Permission Denied Errors
**Symptoms**: Permission errors in WSL workspace
**Solution**:
```bash
sudo chmod -R 755 /var/lib/jenkins/workspace/Application/
sudo chown -R jenkins:jenkins /var/lib/jenkins/workspace/Application/
```

### Issue 3: Port Already in Use
**Symptoms**: "Port already in use" during deployment
**Solution**:
```bash
# Check what's using the port
netstat -tlnp | grep 8080
# Kill the process or change port in docker-compose.yml
```

### Issue 4: Out of Disk Space
**Symptoms**: "No space left on device"
**Solution**:
```bash
# Clean Docker resources
docker system prune -a -f
docker volume prune -f
```

### Issue 5: Maven Build Failures
**Symptoms**: Compilation or test failures
**Solutions**:
- Check Java version compatibility
- Verify internet connectivity for dependency downloads
- Check for proxy configurations if behind corporate firewall

### Issue 6: Health Check Timeouts
**Symptoms**: Services don't respond during health checks
**Solutions**:
- Increase health check timeout values
- Check container logs: `docker-compose logs [service-name]`
- Verify service configurations

## Manual Verification Steps

After successful deployment, verify manually:

1. **Application Access**:
   ```bash
   curl http://localhost:8080
   curl http://localhost:8080/actuator/health
   ```

2. **Database Connectivity**:
   ```bash
   docker exec -it mysql mysql -u root -p
   ```

3. **Monitoring Stack**:
   ```bash
   # Check Prometheus targets
   curl http://localhost:9090/api/v1/targets
   
   # Check Grafana API
   curl http://localhost:3000/api/health
   ```

4. **Container Status**:
   ```bash
   docker-compose ps
   docker stats
   ```

## Customization Options

### Modifying Ports
Edit the `docker-compose.yml` file in the deployment directory to change exposed ports:
```yaml
services:
  petclinic-app:
    ports:
      - "8080:8080"  # Change first port for external access
```

### Adding Services
Add new services to the `docker-compose.yml`:
```yaml
  new-service:
    image: example/service:latest
    ports:
      - "9999:9999"
    depends_on:
      - mysql
```

### Environment-Specific Configurations
Create environment-specific compose files:
- `docker-compose.dev.yml`
- `docker-compose.prod.yml`

Use with: `docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d`

## Security Considerations

1. **Default Passwords**: Change default passwords in production
   - Grafana: admin/admin123
   - MySQL: Check docker-compose.yml for root password

2. **Network Security**: Consider using Docker networks for service isolation

3. **Volume Permissions**: Ensure data volumes have appropriate permissions

4. **Firewall Rules**: Configure host firewall for exposed ports

## Maintenance Tasks

### Regular Cleanup
```bash
# Weekly Docker cleanup
docker system prune -f
docker volume prune -f

# Remove old images
docker images -f "dangling=true" -q | xargs -r docker rmi
```

### Log Management
```bash
# View logs with timestamps
docker-compose logs -t --tail=100

# Follow logs in real-time
docker-compose logs -f [service-name]
```

### Backup Procedures
```bash
# Backup MySQL data
docker exec mysql mysqldump -u root -p database_name > backup.sql

# Backup Grafana configurations
docker cp grafana_container:/var/lib/grafana ./grafana-backup
```

## Performance Tuning

### Memory Optimization
- Adjust JVM heap size in Dockerfile
- Configure Docker container memory limits
- Monitor memory usage with `docker stats`

### Database Optimization
- Configure MySQL buffer pool size
- Set up proper indexing
- Regular database maintenance

## Integration with Other Tools

### CI/CD Integration
- Integrate with GitHub webhooks
- Add Slack/email notifications
- Include security scanning stages

### Monitoring Integration
- Configure alerting rules in Prometheus
- Set up Grafana dashboards for application metrics
- Integrate with external monitoring systems

This comprehensive guide covers all aspects of the Jenkins pipeline for deploying the PetClinic application with full monitoring stack in a WSL environment.