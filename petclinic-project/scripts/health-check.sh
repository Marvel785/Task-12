#!/bin/bash
echo "Checking application health..."

# Check PetClinic application
if curl -s http://localhost:8080/actuator/health | grep -q "UP"; then
    echo "✅ PetClinic application is healthy"
else
    echo "❌ PetClinic application is not responding"
fi

# Check Prometheus
if curl -s http://localhost:9090/-/ready 2>/dev/null | grep -q "Prometheus is Ready"; then
    echo "✅ Prometheus is ready"
else
    echo "❌ Prometheus is not ready"
fi

# Check Grafana
if curl -s http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not responding"
fi
