#!/usr/bin/env bash
# HermesShell — one-command install + onboard.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ppritcha/hermesshell/main/scripts/install.sh | bash
#
# What it does:
#   1. Verifies bash, curl, docker, git are present and the Docker daemon is running.
#   2. Installs Node.js (via nvm) if not already present.
#   3. Clones (or updates, if clean) the repo at $HERMESSHELL_HOME (default ~/.hermesshell).
#   4. Builds the Node.js CLI (npm install + build) and links it globally.
#   5. Runs `hermesshell onboard` to configure inference, policy, and create the sandbox.
#
# Overrides (env vars):
#   HERMESSHELL_HOME                — install location (default: ~/.hermesshell)
#   HERMESSHELL_REF                 — git ref to check out (default: main)
#   HERMESSHELL_PROVIDER            — skip provider prompt (non-interactive onboard)
#   HERMESSHELL_MODEL               — skip model prompt (non-interactive onboard)
#   HERMESSHELL_POLICY_TIER         — skip tier prompt (non-interactive onboard)
#   HERMESSHELL_SKIP_ONBOARD        — set to 1 to install without running onboard
#
# Forwarded to the sandbox (override upstream Hermes defaults):
#   HERMES_KANBAN_CLAIM_TTL_SECONDS — kanban worker heartbeat TTL (default 900s)
#   HERMES_API_TIMEOUT              — Hermes API call timeout (default 1800s)
#   HERMES_API_CALL_STALE_TIMEOUT   — Hermes stale-call timeout (default 900s)

set -euo pipefail

REPO_URL="${HERMESSHELL_REPO_URL:-https://github.com/ppritcha/hermesshell.git}"
REF="${HERMESSHELL_REF:-main}"
INSTALL_DIR="${HERMESSHELL_HOME:-$HOME/.hermesshell}"
NODE_MIN_VERSION=20

BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; RESET='\033[0m'

say()     { printf "%b\n" "$*"; }
ok()      { say "  ${GREEN}✓${RESET} $*"; }
warn()    { say "  ${YELLOW}!${RESET} $*"; }
err()     { say "  ${RED}✗${RESET} $*" >&2; exit 1; }
heading() { printf "\n${BOLD}%s${RESET}\n" "$*"; }

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
heading "Checking prerequisites"
for cmd in bash curl docker git; do
    command -v "$cmd" >/dev/null 2>&1 || err "$cmd not found. Install it and retry."
done
if ! docker info >/dev/null 2>&1; then
    err "Docker daemon is not running. Start Docker Desktop (macOS/Windows) or 'sudo systemctl start docker' (Linux) and retry."
fi
ok "bash, curl, docker, git present; Docker daemon running"

# ── 2. Install Node.js if missing ─────────────────────────────────────────────
heading "Checking Node.js"

_node_version_ok() {
    if ! command -v node >/dev/null 2>&1; then return 1; fi
    local ver
    ver=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
    [ -n "$ver" ] && [ "$ver" -ge "$NODE_MIN_VERSION" ]
}

if _node_version_ok; then
    ok "Node.js $(node --version) already installed"
else
    say "  Node.js >= ${NODE_MIN_VERSION} not found. Installing via nvm..."
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    fi
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm install "$NODE_MIN_VERSION"
    nvm use "$NODE_MIN_VERSION"

    if _node_version_ok; then
        ok "Node.js $(node --version) installed via nvm"
    else
        err "Failed to install Node.js >= $NODE_MIN_VERSION. Install manually and retry."
    fi
fi

# ── 3. Clone or update repo ───────────────────────────────────────────────────
heading "Fetching HermesShell sources into $INSTALL_DIR"
if [ -d "$INSTALL_DIR/.git" ]; then
    if ! git -C "$INSTALL_DIR" diff --quiet HEAD -- 2>/dev/null; then
        warn "Existing checkout at $INSTALL_DIR has local changes; skipping update."
        warn "Commit or stash and re-run, or set HERMESSHELL_HOME to a fresh path."
    else
        git -C "$INSTALL_DIR" fetch --tags --quiet origin
        git -C "$INSTALL_DIR" checkout --quiet "$REF"
        git -C "$INSTALL_DIR" pull --quiet --ff-only origin "$REF" || true
        ok "Updated existing install to $REF"
    fi
else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --quiet --branch "$REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
    ok "Cloned $REPO_URL ($REF) to $INSTALL_DIR"
fi

# ── 4. Bootstrap .env ─────────────────────────────────────────────────────────
if [ ! -f "$INSTALL_DIR/.env" ] && [ -f "$INSTALL_DIR/.env.example" ]; then
    cp "$INSTALL_DIR/.env.example" "$INSTALL_DIR/.env"
    ok "Created $INSTALL_DIR/.env from .env.example"
fi

# ── 5. Build and link the Node.js CLI ─────────────────────────────────────────
heading "Building HermesShell CLI"
cd "$INSTALL_DIR/cli"
npm install --no-fund --no-audit 2>&1 | tail -1
npm run build 2>&1 | tail -1
ok "CLI built at $INSTALL_DIR/cli/dist/"

heading "Installing hermesshell CLI globally"
if npm link 2>/dev/null; then
    ok "hermesshell linked globally via npm"
elif command -v sudo >/dev/null 2>&1; then
    warn "npm link failed; retrying with sudo..."
    if sudo npm link 2>/dev/null; then
        ok "hermesshell linked globally via sudo npm link"
    else
        warn "Global link failed. Add to your PATH manually:"
        say "    export PATH=\"$INSTALL_DIR/cli/node_modules/.bin:\$PATH\""
    fi
else
    warn "npm link failed and sudo unavailable. Add to PATH manually:"
    say "    export PATH=\"$INSTALL_DIR/cli/node_modules/.bin:\$PATH\""
fi

# Verify the CLI is available
if ! command -v hermesshell >/dev/null 2>&1; then
    export PATH="$INSTALL_DIR/cli/node_modules/.bin:$PATH"
fi

if command -v hermesshell >/dev/null 2>&1; then
    ok "hermesshell CLI available: $(which hermesshell)"
else
    err "hermesshell not found on PATH after install. Check the output above."
fi

# ── 6. Run onboard ────────────────────────────────────────────────────────────
if [ "${HERMESSHELL_SKIP_ONBOARD:-}" = "1" ]; then
    heading "Skipping onboard (HERMESSHELL_SKIP_ONBOARD=1)"
    say ""
    say "Run onboard manually when ready:"
    say "  ${CYAN}hermesshell onboard${RESET}"
else
    heading "Starting HermesShell onboard"

    ONBOARD_ARGS=()
    if [ -n "${HERMESSHELL_PROVIDER:-}" ]; then
        ONBOARD_ARGS+=(--non-interactive)
    fi

    hermesshell onboard "${ONBOARD_ARGS[@]+"${ONBOARD_ARGS[@]}"}"
fi
