#!/bin/bash

# start_novnc.sh — Start VNC server and noVNC web proxy (HTTPS)
# Author: SkyzFallin (https://github.com/SkyzFallin)
# Starts tightvncserver on display :1 and launches the noVNC websocket proxy
# on port 6080 with TLS (HTTPS). Cert is generated during install.

CERT_FILE="/etc/novnc-certs/novnc.pem"
NOVNC_PROXY="/opt/noVNC/utils/novnc_proxy"

echo "[+] Starting noVNC Environment..."

# --- Sanity checks ---
if [[ ! -f "$CERT_FILE" ]]; then
    echo "[!] TLS certificate not found at $CERT_FILE"
    echo "    Run: sudo ./install-novnc.sh"
    exit 1
fi

if [[ ! -f "$NOVNC_PROXY" ]]; then
    echo "[!] novnc_proxy not found at $NOVNC_PROXY"
    echo "    Run: sudo ./install-novnc.sh"
    exit 1
fi

# --- Start VNC Server ---
echo "[+] Starting VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24

sleep 3

# --- Start noVNC with TLS ---
echo "[+] Starting noVNC proxy (HTTPS)..."
pkill -f novnc_proxy 2>/dev/null || true
nohup "$NOVNC_PROXY" \
    --vnc localhost:5901 \
    --listen 6080 \
    --ssl-only \
    --cert "$CERT_FILE" \
    > /tmp/novnc.log 2>&1 &

sleep 2

# --- Status check ---
echo ""
echo "[+] Status Check:"
echo "-------------------"

if ss -tlnp | grep -q 5901; then
    echo "✓ VNC Server:   Running on port 5901"
else
    echo "✗ VNC Server:   NOT running"
fi

if ss -tlnp | grep -q 6080; then
    echo "✓ noVNC Proxy:  Running on port 6080 (HTTPS)"
else
    echo "✗ noVNC Proxy:  NOT running — check /tmp/novnc.log"
fi

echo ""
echo "[+] Access noVNC at: https://localhost:6080/vnc.html"
echo "    Note: Accept the self-signed certificate warning in your browser."
echo ""
