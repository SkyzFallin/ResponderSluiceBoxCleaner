#!/usr/bin/env bash
set -euo pipefail

# install-novnc.sh — Install and configure noVNC + VNC server on Kali/Debian/Ubuntu
# Author: SkyzFallin (https://github.com/SkyzFallin)
# Usage: sudo ./install-novnc.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)." >&2
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Install dependencies ---
echo "[*] Installing dependencies..."
apt update -qq
apt install -y tightvncserver git xfce4 xfce4-goodies dbus-x11 openssl

# --- Prompt for VNC password ---
echo ""
echo "[*] Set a VNC password."
echo "    Requirements: at least 6 characters, cannot be 'password'."
echo ""

while true; do
    read -rsp "    Enter VNC password: " VNC_PASS
    echo ""

    if [[ -z "$VNC_PASS" ]]; then
        echo "    [!] Password cannot be empty. Try again."
        continue
    fi

    if [[ "${VNC_PASS,,}" == "password" ]]; then
        echo "    [!] 'password' is not allowed. Try again."
        continue
    fi

    if [[ ${#VNC_PASS} -lt 6 ]]; then
        echo "    [!] Password must be at least 6 characters. Try again."
        continue
    fi

    read -rsp "    Confirm VNC password: " VNC_PASS_CONFIRM
    echo ""

    if [[ "$VNC_PASS" != "$VNC_PASS_CONFIRM" ]]; then
        echo "    [!] Passwords do not match. Try again."
        continue
    fi

    break
done

# --- Set up VNC password ---
echo "[*] Setting up VNC password..."
sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.vnc"
echo "$VNC_PASS" | sudo -u "$REAL_USER" vncpasswd -f > "$REAL_HOME/.vnc/passwd"
chmod 600 "$REAL_HOME/.vnc/passwd"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.vnc/passwd"
unset VNC_PASS VNC_PASS_CONFIRM

echo "[+] VNC password set."

# --- Generate self-signed TLS certificate for HTTPS ---
CERT_DIR="/etc/novnc-certs"
CERT_FILE="$CERT_DIR/novnc.pem"

if [[ -f "$CERT_FILE" ]]; then
    echo "[*] TLS certificate already exists at $CERT_FILE, skipping generation."
else
    echo "[*] Generating self-signed TLS certificate..."
    mkdir -p "$CERT_DIR"
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout "$CERT_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=novnc-local" \
        -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" \
        2>/dev/null
    chmod 600 "$CERT_FILE"
    echo "[+] Certificate written to $CERT_FILE (valid 10 years)."
fi

# --- Create VNC xstartup ---
echo "[*] Creating VNC xstartup script..."
cat > "$REAL_HOME/.vnc/xstartup" << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
chmod +x "$REAL_HOME/.vnc/xstartup"
chown "$REAL_USER:$REAL_USER" "$REAL_HOME/.vnc/xstartup"

# --- Clone noVNC ---
if [[ -d /opt/noVNC ]]; then
    echo "[*] noVNC already installed at /opt/noVNC, skipping clone."
else
    echo "[*] Cloning noVNC to /opt/noVNC..."
    git clone https://github.com/novnc/noVNC.git /opt/noVNC
fi

# --- Install start/stop scripts ---
echo "[*] Installing start/stop scripts to /usr/local/bin..."
cp "$SCRIPT_DIR/start_novnc.sh" /usr/local/bin/start-novnc
cp "$SCRIPT_DIR/stop_novnc.sh" /usr/local/bin/stop-novnc
chmod +x /usr/local/bin/start-novnc /usr/local/bin/stop-novnc

# --- Done ---
echo ""
echo "[+] Installation complete."
echo ""
echo "    Commands:"
echo "      start-novnc    Start VNC server + noVNC proxy (HTTPS)"
echo "      stop-novnc     Stop everything"
echo ""
echo "    Access: https://localhost:6080/vnc.html"
echo "    Note: Your browser will warn about the self-signed certificate."
echo "          Accept it once and the warning won't recur for this host."
echo ""
echo "    To change your VNC password later: vncpasswd"
echo ""
