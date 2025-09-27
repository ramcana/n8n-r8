#!/bin/bash
# Setup monitoring data directories with proper permissions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$MONITORING_DIR/data"

echo "Setting up monitoring data directories..."

# Create directories if they don't exist
mkdir -p "$DATA_DIR"/{prometheus,grafana,loki,alertmanager,uptime-kuma}

# Set permissions for Loki (runs as user 10001)
echo "Setting Loki permissions..."
sudo chown -R 10001:10001 "$DATA_DIR/loki" 2>/dev/null || {
    echo "Warning: Could not set Loki ownership. Trying alternative approach..."
    chmod -R 777 "$DATA_DIR/loki"
}

# Set permissions for Grafana (runs as user 472)
echo "Setting Grafana permissions..."
sudo chown -R 472:472 "$DATA_DIR/grafana" 2>/dev/null || {
    echo "Warning: Could not set Grafana ownership. Trying alternative approach..."
    chmod -R 777 "$DATA_DIR/grafana"
}

# Set permissions for Prometheus (runs as user 65534)
echo "Setting Prometheus permissions..."
sudo chown -R 65534:65534 "$DATA_DIR/prometheus" 2>/dev/null || {
    echo "Warning: Could not set Prometheus ownership. Trying alternative approach..."
    chmod -R 777 "$DATA_DIR/prometheus"
}

# Set permissions for Alertmanager (runs as user 65534)
echo "Setting Alertmanager permissions..."
sudo chown -R 65534:65534 "$DATA_DIR/alertmanager" 2>/dev/null || {
    echo "Warning: Could not set Alertmanager ownership. Trying alternative approach..."
    chmod -R 777 "$DATA_DIR/alertmanager"
}

# Set permissions for Uptime Kuma (runs as user 1000)
echo "Setting Uptime Kuma permissions..."
sudo chown -R 1000:1000 "$DATA_DIR/uptime-kuma" 2>/dev/null || {
    echo "Warning: Could not set Uptime Kuma ownership. Trying alternative approach..."
    chmod -R 777 "$DATA_DIR/uptime-kuma"
}

echo "✅ Monitoring directories setup complete!"
echo "Data directory: $DATA_DIR"
ls -la "$DATA_DIR"