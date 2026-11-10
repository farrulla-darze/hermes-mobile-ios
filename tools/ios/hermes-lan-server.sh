#!/usr/bin/env bash
# Expose a local Hermes install to Hermes Mobile iOS over the home LAN.
#
#   * enables the API server on 0.0.0.0:8642 with a bearer key
#   * runs the dashboard on 0.0.0.0:9119 behind username/password (basic auth)
#     as a LaunchAgent (ai.hermes.dashboard-lan), so it survives reboots
#   * restarts the Hermes gateway so the API server comes up
#
# Run it from a normal Terminal window (NOT from inside a Hermes chat: the
# gateway restart would kill that session). Idempotent: existing keys are kept.
# Credentials end up in ~/.hermes/hermes-mobile-ios-credentials.txt (mode 600).
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ENV_FILE="$HERMES_HOME/.env"
CRED_FILE="$HERMES_HOME/hermes-mobile-ios-credentials.txt"
LABEL="ai.hermes.dashboard-lan"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
HERMES_BIN="$(command -v hermes)"
DASH_USER="${DASH_USER:-$(id -un | cut -c1-16)}"
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"

touch "$ENV_FILE"
if ! grep -q '^API_SERVER_KEY=' "$ENV_FILE"; then
  echo "Generating API key and dashboard credentials..."
  python3 - "$ENV_FILE" "$CRED_FILE" "$DASH_USER" "$LAN_IP" <<'PY'
import base64, hashlib, os, secrets, sys
env, cred, user, ip = sys.argv[1:]
def scrypt_hash(pw):  # same format as plugins.dashboard_auth.basic.hash_password
    salt = secrets.token_bytes(16)
    dk = hashlib.scrypt(pw.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32, maxmem=0)
    return f"scrypt${2**14}$8$1${base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}"
key, pw, sec = secrets.token_urlsafe(32), secrets.token_urlsafe(12), secrets.token_urlsafe(48)
with open(env, "a") as f:
    f.write(f"\n# Hermes Mobile iOS (LAN access)\nAPI_SERVER_ENABLED=true\nAPI_SERVER_HOST=0.0.0.0\n"
            f"API_SERVER_KEY={key}\nHERMES_DASHBOARD_BASIC_AUTH_USERNAME={user}\n"
            f"HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH={scrypt_hash(pw)}\n"
            f"HERMES_DASHBOARD_BASIC_AUTH_SECRET={sec}\n")
with open(cred, "w") as f:
    f.write(f"API server URL: http://{ip}:8642\nAPI key: {key}\n"
            f"Dashboard URL: http://{ip}:9119\nDashboard user: {user}\nDashboard password: {pw}\n")
os.chmod(cred, 0o600)
PY
else
  echo "API_SERVER_KEY already set in $ENV_FILE; keeping existing credentials."
fi

mkdir -p "$HERMES_HOME/logs" "$(dirname "$PLIST")"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$HERMES_BIN</string><string>dashboard</string>
    <string>--host</string><string>0.0.0.0</string>
    <string>--port</string><string>9119</string>
    <string>--no-open</string><string>--skip-build</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>StandardOutPath</key><string>$HERMES_HOME/logs/dashboard-lan.log</string>
  <key>StandardErrorPath</key><string>$HERMES_HOME/logs/dashboard-lan.log</string>
</dict></plist>
EOF
plutil -lint "$PLIST" >/dev/null

echo "Starting dashboard LaunchAgent..."
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "Restarting Hermes gateway (enables the API server)..."
"$HERMES_BIN" gateway restart

echo "Waiting for services..."
for _ in $(seq 1 60); do
  api=$(curl -s -o /dev/null -w '%{http_code}' "http://$LAN_IP:8642/health" || true)
  dash=$(curl -s -o /dev/null -w '%{http_code}' "http://$LAN_IP:9119/api/status" || true)
  [ "$api" = 200 ] && [ "$dash" = 200 ] && break
  sleep 2
done
echo "API server  http://$LAN_IP:8642/health      -> $api"
echo "Dashboard   http://$LAN_IP:9119/api/status  -> $dash"
echo "Credentials: $CRED_FILE"
