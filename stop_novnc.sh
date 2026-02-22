#!/bin/bash

# stop_novnc.sh — Stop VNC server and noVNC web proxy
# Author: SkyzFallin (https://github.com/SkyzFallin)
# Kills the noVNC websocket proxy and VNC server on display :1.

echo "[+] Stopping noVNC Environment..."

# Stop noVNC
echo "[+] Stopping noVNC proxy..."
pkill -f novnc_proxy

# Stop VNC
echo "[+] Stopping VNC server..."
vncserver -kill :1

echo "[+] noVNC Environment stopped."
