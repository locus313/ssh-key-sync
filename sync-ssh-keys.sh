#!/bin/bash
set -euo pipefail

# shellcheck disable=SC2034  # planned to be used in a future release
SCRIPT_VERSION="0.0.6"

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

log_message() {
  local TIMESTAMP
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$TIMESTAMP: $1"
}

fetch_key_file() {
  local METHOD="$1"
  local TARGET="$2"
  local OUTFILE="$3"

  if [[ "$METHOD" == "raw" ]]; then
    curl -fsSL "$TARGET" -o "$OUTFILE"
    return $?
  elif [[ "$METHOD" == "api" ]]; then
    : "${GITHUB_TOKEN:?GITHUB_TOKEN is required for API access}"
    curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
               -H "Accept: application/vnd.github.v3.raw" \
               "$TARGET" -o "$OUTFILE"
    return $?
  elif [[ "$METHOD" == "ghuser" ]]; then
    # TARGET is the GitHub username
    curl -fsSL "https://github.com/${TARGET}.keys" -o "$OUTFILE"
    return $?
  else
    log_message "Error: Unsupported method '$METHOD' encountered for URL '$TARGET'. Halting execution."
    exit 2
  fi
}

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
    log_message "Created .ssh directory for user '$USER'"
  fi

  log_message "Fetching key file for $USER from $URL (method: $METHOD)"
  if ! fetch_key_file "$METHOD" "$URL" "$TMP_FILE"; then
    log_message "Failed to fetch key file for user '$USER' from $URL. Skipping."
    continue
  fi

  if [ ! -f "$AUTH_KEYS" ] || ! cmp -s "$TMP_FILE" "$AUTH_KEYS"; then
    cp "$TMP_FILE" "$AUTH_KEYS"
    chown "$USER:$USER" "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    log_message "Updated authorized_keys for user '$USER'"
  else
    log_message "No changes for user '$USER'"
  fi
done
