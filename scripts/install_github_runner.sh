#!/usr/bin/env bash
# Install and register GitHub Actions self-hosted runner. Run on bootstrap VM via Azure Run Command.
# Azure Run Command runs as root; the runner must NOT run as root ("Must not run with sudo").
# This script creates a dedicated user, runs config.sh as that user, and installs a systemd unit (as root) that runs the runner as that user.
# Usage: RUNNER_TOKEN=<token> REPO=<owner/repo> [RUNNER_VERSION=2.321.0] ./install_github_runner.sh
# Token: from POST /repos/{owner}/{repo}/actions/runners/registration-token (use PAT with repo admin).

set -euo pipefail

RUNNER_TOKEN="${RUNNER_TOKEN:?Set RUNNER_TOKEN (registration token)}"
REPO="${REPO:?Set REPO (owner/repo)}"
RUNNER_VERSION="${RUNNER_VERSION:-2.321.0}"
RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

echo "Installing GitHub Actions runner v${RUNNER_VERSION} for ${REPO} (as user ${RUNNER_USER})..."

# Dependencies (as root)
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)
command -v tar >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq tar)

# Dedicated user (runner refuses to run as root)
if ! id -u "$RUNNER_USER" &>/dev/null; then
  echo "Creating user ${RUNNER_USER}..."
  useradd --system --create-home --shell /bin/bash "$RUNNER_USER"
fi

# Allow runner user to run sudo without password (needed for "Install PostgreSQL client" step in bootstrap job)
echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${RUNNER_USER}"
chmod 0440 "/etc/sudoers.d/${RUNNER_USER}"

# Install or replace existing (root prepares dir and bits)
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
SVC_NAME="actions-runner-retailflow"
if systemctl is-active --quiet "${SVC_NAME}.service" 2>/dev/null; then
  echo "Stopping existing runner service..."
  systemctl stop "${SVC_NAME}.service" || true
fi
if [[ -f config.sh ]]; then
  runuser -u "$RUNNER_USER" -- bash -c "cd $RUNNER_DIR && (./svc.sh stop 2>/dev/null || true; ./svc.sh uninstall 2>/dev/null || true)" || true
fi
curl -sSfL -o runner.tar.gz "$RUNNER_URL"
tar xzf runner.tar.gz
rm -f runner.tar.gz
chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"

# If runner was already configured (e.g. from a previous register_only), remove so we can re-register with the new token.
if [[ -f "$RUNNER_DIR/config.sh" ]] && [[ -f "$RUNNER_DIR/.runner" ]]; then
  echo "Removing existing runner configuration so we can re-register..."
  runuser -u "$RUNNER_USER" -- bash -c "cd $RUNNER_DIR && ./config.sh remove --unattended" || true
fi

# config.sh must run as non-root; svc.sh install requires root but would run service as root. Use a custom systemd unit.
runuser -u "$RUNNER_USER" -- env RUNNER_TOKEN="$RUNNER_TOKEN" bash -c "cd $RUNNER_DIR && ./config.sh --url 'https://github.com/${REPO}' --token \"\$RUNNER_TOKEN\" --labels 'self-hosted,linux' --unattended --replace"

cat > "/etc/systemd/system/${SVC_NAME}.service" << EOF
[Unit]
Description=GitHub Actions Runner (RetailFlow)
After=network.target

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${RUNNER_DIR}
ExecStart=${RUNNER_DIR}/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable "${SVC_NAME}.service"
systemctl start "${SVC_NAME}.service"

echo "Runner installed and started (running as ${RUNNER_USER})."
