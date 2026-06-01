#!/bin/bash
set -euo pipefail

# Find workspace root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_ENV_LOCAL="$ROOT_DIR/frontend/.env.local"
LOG_FILE="$ROOT_DIR/scripts/deployments.log"

# Default values
NETWORK="testnet"
SOURCE="deployer"
WASM="$ROOT_DIR/contracts/stellar-give/target/wasm32-unknown-unknown/release/stellar_give.wasm"

usage() {
  cat <<USAGE
Usage:
  ./scripts/deploy-contract.sh [network] [source] [wasm_path]
  OR with explicit flags:
  ./scripts/deploy-contract.sh --network <network> --source <source> --wasm <wasm_path>

Defaults:
  network:   testnet
  source:    deployer
  wasm:      contracts/stellar-give/target/wasm32-unknown-unknown/release/stellar_give.wasm
USAGE
}

# Parse parameters (supports both positional and flags)
POS_COUNT=1
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --wasm)
      WASM="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "error: unknown option $1" >&2
      usage
      exit 1
      ;;
    *)
      # Positional arguments mapping
      if [ "$POS_COUNT" -eq 1 ]; then
        NETWORK="$1"
      elif [ "$POS_COUNT" -eq 2 ]; then
        SOURCE="$1"
      elif [ "$POS_COUNT" -eq 3 ]; then
        WASM="$1"
      else
        echo "error: too many positional arguments: $1" >&2
        usage
        exit 1
      fi
      POS_COUNT=$((POS_COUNT + 1))
      shift
      ;;
  esac
done

# Ensure logs directory exists
mkdir -p "$(dirname "$LOG_FILE")"
echo "=== Deployment Attempt: $(date) ===" >> "$LOG_FILE"
echo "Network: $NETWORK" >> "$LOG_FILE"
echo "Source: $SOURCE" >> "$LOG_FILE"
echo "WASM Path: $WASM" >> "$LOG_FILE"

# Detect CLI tool
if command -v soroban >/dev/null 2>&1; then
  CLI="soroban"
elif command -v stellar >/dev/null 2>&1; then
  CLI="stellar"
else
  echo "error: neither 'soroban' nor 'stellar' CLI found in PATH" | tee -a "$LOG_FILE" >&2
  exit 1
fi
echo "Using CLI: $CLI" >> "$LOG_FILE"

# Backup .env.local if it exists
if [ -f "$FRONTEND_ENV_LOCAL" ]; then
  echo "Backing up frontend/.env.local to frontend/.env.local.bak..."
  cp "$FRONTEND_ENV_LOCAL" "$FRONTEND_ENV_LOCAL.bak"
else
  echo "Creating new frontend/.env.local..."
  touch "$FRONTEND_ENV_LOCAL"
  cp "$FRONTEND_ENV_LOCAL" "$FRONTEND_ENV_LOCAL.bak"
fi

# Error handling trap: Rollback on error
cleanup_on_failure() {
  EXIT_CODE=$?
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "❌ Deployment failed! Exit code: $EXIT_CODE" | tee -a "$LOG_FILE" >&2
    if [ -f "$FRONTEND_ENV_LOCAL.bak" ]; then
      echo "Rolling back frontend/.env.local..." | tee -a "$LOG_FILE" >&2
      mv "$FRONTEND_ENV_LOCAL.bak" "$FRONTEND_ENV_LOCAL"
    fi
  fi
}
trap cleanup_on_failure EXIT

# Check if WASM exists. If not, try to build it first.
if [ ! -f "$WASM" ]; then
  echo "WASM not found at $WASM. Attempting contract build..." | tee -a "$LOG_FILE"
  if [ -d "$ROOT_DIR/contracts/stellar-give" ]; then
    (
      cd "$ROOT_DIR/contracts/stellar-give"
      rustup target add wasm32-unknown-unknown >/dev/null 2>&1 || true
      cargo build --target wasm32-unknown-unknown --release
    )
  else
    echo "error: WASM not found and cannot build contract since contracts/stellar-give/ directory is missing" | tee -a "$LOG_FILE" >&2
    exit 1
  fi
fi

# Confirm WASM exists now
if [ ! -f "$WASM" ]; then
  echo "error: compiled wasm file not found at $WASM" | tee -a "$LOG_FILE" >&2
  exit 1
fi

echo "Deploying to $NETWORK..." | tee -a "$LOG_FILE"

# Run deploy and capture the output
# Note: we redirect stderr to stdout to capture any errors as well as success details
DEPLOY_OUTPUT=$($CLI contract deploy --wasm "$WASM" --network "$NETWORK" --source "$SOURCE" 2>&1)
echo "$DEPLOY_OUTPUT" >> "$LOG_FILE"

# Extract contract ID from the output (e.g. C[A-Z0-9]{55})
# We use standard grep compatible with Mac and Linux
CONTRACT_ID=$(echo "$DEPLOY_OUTPUT" | grep -Eo 'C[A-Z0-9]{55}' | head -n 1 || true)

if [ -z "$CONTRACT_ID" ]; then
  echo "error: failed to extract contract ID from deployment output" | tee -a "$LOG_FILE" >&2
  echo "Deployment output: $DEPLOY_OUTPUT" >> "$LOG_FILE"
  exit 1
fi

echo "Extracted Contract ID: $CONTRACT_ID" | tee -a "$LOG_FILE"

# Update frontend/.env.local
echo "Updating frontend/.env.local..." | tee -a "$LOG_FILE"
if grep -q "NEXT_PUBLIC_CONTRACT_ID=" "$FRONTEND_ENV_LOCAL"; then
  # Mac/Linux cross-compatible replace using perl
  perl -pi -e "s/NEXT_PUBLIC_CONTRACT_ID=.*/NEXT_PUBLIC_CONTRACT_ID=$CONTRACT_ID/" "$FRONTEND_ENV_LOCAL"
else
  # If NEXT_PUBLIC_CONTRACT_ID is not present, make sure we append it neatly
  # Handle missing trailing newline
  if [ -s "$FRONTEND_ENV_LOCAL" ] && [ "$(tail -c 1 "$FRONTEND_ENV_LOCAL" | wc -l)" -eq 0 ]; then
    echo "" >> "$FRONTEND_ENV_LOCAL"
  fi
  echo "NEXT_PUBLIC_CONTRACT_ID=$CONTRACT_ID" >> "$FRONTEND_ENV_LOCAL"
fi

# Clean up trap and backup
trap - EXIT
rm -f "$FRONTEND_ENV_LOCAL.bak"

echo "✅ Deployed $CONTRACT_ID to $NETWORK successfully!" | tee -a "$LOG_FILE"
