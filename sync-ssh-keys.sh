#!/bin/bash
set -euo pipefail

# === Configuration: user -> remote key file URL ===
declare -A USER_KEYS=(
  ["ubuntu"]="https://example.com/ssh-keys/ubuntu.authorized_keys"
  ["devuser"]="https://example.com/ssh-keys/devuser.authorized_keys"
  ["admin"]="https://example.com/ssh-keys/admin.authorized_keys"
)

log_message() {
  local TIMESTAMP
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$TIMESTAMP: $1"
}

TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT
for USER in "${!USER_KEYS[@]}"; do
  TMP_FILE=$(mktemp)
  TMP_FILES+=("$TMP_FILE")
  URL="${USER_KEYS[$USER]}"
  USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
  if [ -z "$USER_HOME" ]; then
    log_message "Failed to determine home directory for user '$USER'. Skipping."
    continue
  fi
  AUTH_KEYS="$USER_HOME/.ssh/authorized_keys"
  SSH_DIR="$(dirname "$AUTH_KEYS")"

  # Ensure user exists
  if ! id "$USER" &>/dev/null; then
    log_message "User '$USER' does not exist. Skipping."
    continue
  fi

  # Create .ssh directory if it doesn't exist
  if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chown "$USER:$USER" "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    log_message "Created .ssh directory for user '$USER'"
  fi

  # Fetch remote key file
  if curl -fsSL "$URL" -o "$TMP_FILE"; then
    if [ ! -f "$AUTH_KEYS" ] || ! cmp -s "$TMP_FILE" "$AUTH_KEYS"; then
      cp "$TMP_FILE" "$AUTH_KEYS"
      chown "$USER:$USER" "$AUTH_KEYS"
      chmod 600 "$AUTH_KEYS"
      log_message "Updated authorized_keys for user '$USER'"
    else
      echo "$(log_message): No changes for user '$USER'"
    fi
  else
    echo "$(log_message): Failed to download keys for '$USER' from $URL"
  fi
done
