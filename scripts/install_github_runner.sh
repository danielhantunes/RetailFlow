#!/usr/bin/env bash
# Install and register GitHub Actions self-hosted runner. Run on bootstrap VM via Azure Run Command.
# Azure Run Command runs as root; the runner must NOT run as root ("Must not run with sudo").
# This script creates a dedicated user and runs config/svc as that user.
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

# Install or replace existing (root prepares dir and bits)
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
if [[ -f config.sh ]]; then
  echo "Stopping existing runner service..."
  runuser -u "$RUNNER_USER" -- bash -c "cd $RUNNER_DIR && (./svc.sh stop 2>/dev/null || true; ./svc.sh uninstall 2>/dev/null || true)"
fi
curl -sSfL -o runner.tar.gz "$RUNNER_URL"
tar xzf runner.tar.gz
rm -f runner.tar.gz
chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_DIR"

# Configure and install service as non-root (--replace allows re-registration with same token)
runuser -u "$RUNNER_USER" -- env RUNNER_TOKEN="$RUNNER_TOKEN" bash -c "cd $RUNNER_DIR && ./config.sh --url 'https://github.com/${REPO}' --token \"\$RUNNER_TOKEN\" --labels 'self-hosted,linux' --unattended --replace && ./svc.sh install && ./svc.sh start"

echo "Runner installed and started (running as ${RUNNER_USER})."
