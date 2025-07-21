#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034  # planned to be used in a future release
SCRIPT_VERSION="0.0.8"

# === Load user configuration ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$SCRIPT_DIR/users.conf" ]; then
  log_message "Error: Configuration file 'users.conf' not found in $SCRIPT_DIR. Halting execution." >&2
  exit 1
fi
if ! source "$SCRIPT_DIR/users.conf"; then
  log_message "Error: Failed to load configuration file 'users.conf'. Please check the file for syntax errors. Halting execution." >&2
  exit 1
fi

# Load GITHUB_TOKEN from config if set and not already in environment
if [[ -n "${CONF_GITHUB_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
  export GITHUB_TOKEN="$CONF_GITHUB_TOKEN"
fi

log_message() {
  local TIMESTAMP
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$TIMESTAMP: $1"
}

fetch_key_file() {
  local METHOD="$1"
  local TARGET="$2"
  local OUTFILE="$3"
  local RETRIES=3
  local RETRY_DELAY=2

  for ((i=1; i<=RETRIES; i++)); do
    if [[ "$METHOD" == "raw" ]]; then
      curl -fsSL "$TARGET" -o "$OUTFILE" && return 0
    elif [[ "$METHOD" == "api" ]]; then
      : "${GITHUB_TOKEN:?GITHUB_TOKEN is required for API access}"
      curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
                 -H "Accept: application/vnd.github.v3.raw" \
                 "$TARGET" -o "$OUTFILE" && return 0
    elif [[ "$METHOD" == "ghuser" ]]; then
      curl -fsSL "https://github.com/${TARGET}.keys" -o "$OUTFILE" && return 0
    else
      log_message "Error: Unsupported method '$METHOD' encountered for URL '$TARGET'. Halting execution."
      exit 2
    fi

    log_message "Attempt $i/$RETRIES failed for method '$METHOD' and URL '$TARGET'. Retrying in $RETRY_DELAY seconds..."
    sleep "$RETRY_DELAY"
  done

  log_message "Error: All $RETRIES attempts failed for method '$METHOD' and URL '$TARGET'. Skipping."
  return 1
}

self_update() {
  local REPO="locus313/ssh-key-sync"
  local LATEST_URL
  local TMP_DIR

  log_message "Checking for the latest version of the script..."

  LATEST_URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url" | grep "sync-ssh-keys.sh" | cut -d '"' -f 4)

  if [ -z "$LATEST_URL" ]; then
    log_message "Error: Could not determine the latest version URL."
    exit 1
  fi

  TMP_DIR=$(mktemp -d)
  curl -fsSL "$LATEST_URL" -o "$TMP_DIR/sync-ssh-keys.sh"

  if [ ! -s "$TMP_DIR/sync-ssh-keys.sh" ]; then
    log_message "Error: Downloaded script is empty. Aborting update."
    rm -rf "$TMP_DIR"
    exit 1
  fi

  chmod +x "$TMP_DIR/sync-ssh-keys.sh"
  mv "$TMP_DIR/sync-ssh-keys.sh" "$SCRIPT_DIR/sync-ssh-keys.sh"
  rm -rf "$TMP_DIR"

  log_message "Script successfully updated to the latest version."
  exit 0
}

# --- Option parsing ---
if [[ "${1:-}" == "--self-update" ]]; then
  self_update
fi

TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT
for USER in "${!USER_KEYS[@]}"; do
  TMP_FILE=$(mktemp)
  TMP_FILES+=("$TMP_FILE")
  ENTRY="${USER_KEYS[$USER]}"
  METHOD="${ENTRY%%:*}"
  URL="${ENTRY#*:}"

  # Ensure user exists
  if ! id "$USER" &>/dev/null; then
    log_message "User '$USER' does not exist. Skipping."
    continue
  fi

  USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
  if [ -z "$USER_HOME" ]; then
    log_message "Failed to determine home directory for user '$USER'. Skipping."
    continue
  fi

  AUTH_KEYS="$USER_HOME/.ssh/authorized_keys"
  SSH_DIR="$(dirname "$AUTH_KEYS")"

  # Create .ssh directory if it doesn't exist
  if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chown "$USER:$USER" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    log_message "Created .ssh directory for user '$USER' at $SSH_DIR."
  fi

  log_message "Fetching key file for $USER from $URL (method: $METHOD)"
  if ! fetch_key_file "$METHOD" "$URL" "$TMP_FILE"; then
    log_message "Failed to fetch key file for user '$USER' from $URL after multiple attempts. Skipping."
    continue
  fi

  if [ ! -f "$AUTH_KEYS" ]; then
    log_message "No existing authorized_keys file for user '$USER'. Creating a new one."
  elif ! cmp -s "$TMP_FILE" "$AUTH_KEYS"; then
    log_message "Changes detected in authorized_keys for user '$USER'. Updating the file."
  else
    log_message "No changes detected in authorized_keys for user '$USER'."
    continue
  fi

  cp "$TMP_FILE" "$AUTH_KEYS"
  chown "$USER:$USER" "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"
  log_message "Updated authorized_keys for user '$USER' at $AUTH_KEYS."
done
