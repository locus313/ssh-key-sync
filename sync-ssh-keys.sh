#!/bin/bash
set -euo pipefail

# === Configuration: user -> remote key file URL ===
declare -A USER_KEYS=(
  ["ubuntu"]="raw:https://example.com/ssh-keys/ubuntu.authorized_keys"
  ["devuser"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/devuser.authorized_keys?ref=main"
  ["admin"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/admin.authorized_keys?ref=main"
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

  # Fetch remote key file
  if [[ "$METHOD" == "raw" ]]; then
    echo "$LOG_PREFIX: Fetching raw key file for $USER from $URL"
    curl -fsSL "$URL" -o "$TMP_FILE"
  elif [[ "$METHOD" == "api" ]]; then
    echo "$LOG_PREFIX: Fetching API key file for $USER from $URL"
    : "${GITHUB_TOKEN:?GITHUB_TOKEN is required for API access}"
    curl -fsSL -H "Authorization: token $GITHUB_TOKEN" \
               -H "Accept: application/vnd.github.v3.raw" \
               "$URL" -o "$TMP_FILE"; then
    if [ ! -f "$AUTH_KEYS" ] || ! cmp -s "$TMP_FILE" "$AUTH_KEYS"; then
      cp "$TMP_FILE" "$AUTH_KEYS"
      chown "$USER:$USER" "$AUTH_KEYS"
      chmod 600 "$AUTH_KEYS"
      log_message "Updated authorized_keys for user '$USER'"
    else
      log_message "No changes for user '$USER'"
    fi
  else
    log_message "Unknown method '$METHOD' for user '$USER'. Skipping."
    continue
  fi
done
