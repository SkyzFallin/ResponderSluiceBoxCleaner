# YesNoVNC

One-command noVNC setup for Kali Linux. Get browser-based remote desktop access in under a minute — over HTTPS.

**Author:** [SkyzFallin](https://github.com/SkyzFallin)

## Quick Start

```bash
git clone https://github.com/SkyzFallin/YesNoVNC.git
cd YesNoVNC
sudo ./install-novnc.sh
```

The installer will prompt you to set a VNC password — anything except `"password"`. It then generates a self-signed TLS certificate so the session is served over HTTPS.

Then:
```bash
start-novnc     # start VNC server + noVNC proxy (HTTPS)
stop-novnc      # stop everything
```

Access via browser: `https://localhost:6080/vnc.html`

> **Browser warning:** You'll see a self-signed certificate warning on first visit. Accept/trust it once and it won't recur for this host.

## What It Does

The install script handles everything:

- Installs dependencies (`tightvncserver`, `git`, `xfce4`, `dbus-x11`, `openssl`)
- Prompts for a VNC password (enforces non-default, minimum 6 characters)
- Generates a self-signed TLS certificate at `/etc/novnc-certs/novnc.pem`
- Sets up VNC xstartup (with the blank screen fix)
- Clones noVNC to `/opt/noVNC`
- Installs `start-novnc` and `stop-novnc` commands to `/usr/local/bin`

## Details

| Item | Value |
|------|-------|
| VNC Display | `:1` |
| VNC Port | `5901` |
| noVNC Port | `6080` (HTTPS) |
| Resolution | `1920x1080` |
| Desktop | XFCE4 |
| TLS Certificate | `/etc/novnc-certs/novnc.pem` (self-signed, 10 years) |

## Troubleshooting

**Blank screen:** The install script already applies the fix (`unset SESSION_MANAGER` / `unset DBUS_SESSION_BUS_ADDRESS` in `~/.vnc/xstartup`). If you still get a blank screen, restart with `stop-novnc && start-novnc`.

**Can't connect on port 6080:** Make sure you're using `https://` not `http://`. Check that websockify is running: `ps aux | grep websockify`. Check logs: `cat /tmp/novnc.log`.

**Browser certificate warning:** This is expected with a self-signed cert. Click "Advanced" → "Accept the Risk and Continue" (Firefox) or "Proceed to localhost" (Chrome). You only need to do this once per browser.

**Change resolution:** Edit `start_novnc.sh` and change the `-geometry` value (e.g., `2560x1440`, `3840x2160`).

**Change VNC password:** Run `vncpasswd`, then `stop-novnc && start-novnc`.

**Regenerate TLS certificate:** Delete `/etc/novnc-certs/novnc.pem` and re-run `sudo ./install-novnc.sh`.

## Credits

YesNoVNC is a setup and orchestration wrapper around these excellent projects:

- **[noVNC](https://github.com/novnc/noVNC)** — The browser-based VNC client (HTML5/WebSockets). Licensed under [MPL-2.0](https://github.com/novnc/noVNC/blob/master/LICENSE.txt).
- **[websockify](https://github.com/novnc/websockify)** — The WebSocket-to-TCP proxy bundled with noVNC (`novnc_proxy`). Handles the TLS termination for HTTPS. Licensed under [LGPL-3.0](https://github.com/novnc/websockify/blob/master/LICENSE.txt).
- **[TightVNC](https://www.tightvnc.com/)** (`tightvncserver`) — The VNC server running on the host.
- **[XFCE](https://xfce.org/)** — The lightweight desktop environment served over VNC.

## License

GPL-3.0
