#!/usr/bin/env bash
# Install and register GitHub Actions self-hosted runner. Run on bootstrap VM via Azure Run Command.
# Usage: RUNNER_TOKEN=<token> REPO=<owner/repo> [RUNNER_VERSION=2.321.0] ./install_github_runner.sh
# Token: from POST /repos/{owner}/{repo}/actions/runners/registration-token (use PAT with repo admin).

set -euo pipefail

RUNNER_TOKEN="${RUNNER_TOKEN:?Set RUNNER_TOKEN (registration token)}"
REPO="${REPO:?Set REPO (owner/repo)}"
RUNNER_VERSION="${RUNNER_VERSION:-2.321.0}"
RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

echo "Installing GitHub Actions runner v${RUNNER_VERSION} for ${REPO}..."

# Dependencies
command -v curl >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq curl)
command -v tar >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq tar)

# Install or replace existing
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
if [[ -f config.sh ]]; then
  echo "Stopping existing runner service..."
  ./svc.sh stop 2>/dev/null || true
  ./svc.sh uninstall 2>/dev/null || true
fi
curl -sSfL -o runner.tar.gz "$RUNNER_URL"
tar xzf runner.tar.gz
rm -f runner.tar.gz

# Configure and install service (--replace allows re-registration with same token)
./config.sh --url "https://github.com/${REPO}" --token "$RUNNER_TOKEN" --labels "self-hosted,linux" --unattended --replace
./svc.sh install
./svc.sh start

echo "Runner installed and started."
