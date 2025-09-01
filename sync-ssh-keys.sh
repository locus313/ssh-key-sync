#!/bin/bash
set -euo pipefail

# SSH Key Sync Script
# Synchronizes SSH authorized_keys files for multiple users from various sources
# Author: locus313
# Repository: https://github.com/locus313/ssh-key-sync

# shellcheck disable=SC2034  # planned to be used in a future release
readonly SCRIPT_VERSION="0.1.4"
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME

# === Configuration and Constants ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CONFIG_FILE="$SCRIPT_DIR/users.conf"
readonly DEFAULT_RETRIES=3
readonly DEFAULT_RETRY_DELAY=2
readonly GITHUB_REPO="locus313/ssh-key-sync"

# === Utility Functions ===

# Log messages with timestamp
log_message() {
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$timestamp: $1"
}

# Log error messages to stderr
log_error() {
  log_message "ERROR: $1" >&2
}

# Log warning messages
log_warning() {
  log_message "WARNING: $1"
}

# Log info messages
log_info() {
  log_message "INFO: $1"
}

# === Configuration Loading ===

# Load and validate configuration file
load_configuration() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file 'users.conf' not found in $SCRIPT_DIR. Halting execution."
    exit 1
  fi

  # Load GITHUB_TOKEN from config if set and not already in environment
  if [[ -n "${CONF_GITHUB_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
    export GITHUB_TOKEN="$CONF_GITHUB_TOKEN"
    log_info "Using GitHub token from configuration file"
  fi
}

# Validate configuration after sourcing
validate_configuration() {
  # Validate that USER_KEYS array is defined
  if ! declare -p USER_KEYS &>/dev/null; then
    log_error "USER_KEYS array not defined in configuration file. Halting execution."
    exit 1
  fi
}

# === Key Fetching Functions ===

# Validate method parameter
validate_method() {
  local method="$1"
  case "$method" in
    raw|api|ghuser)
      return 0
      ;;
    *)
      log_error "Unsupported method '$method'. Supported methods: raw, api, ghuser"
      return 1
      ;;
  esac
}

# Fetch key file using raw method (public URL)
fetch_raw_key() {
  local url="$1"
  local output_file="$2"
  
  curl -fsSL "$url" -o "$output_file"
}

# Fetch key file using GitHub API method (private repository)
fetch_api_key() {
  local url="$1"
  local output_file="$2"
  
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log_error "GITHUB_TOKEN is required for API access"
    return 1
  fi
  
  curl -fsSL \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3.raw" \
    "$url" -o "$output_file"
}

# Fetch key file using GitHub user method (public keys)
fetch_ghuser_key() {
  local username="$1"
  local output_file="$2"
  
  curl -fsSL "https://github.com/${username}.keys" -o "$output_file"
}

# Main key fetching function with retry logic
fetch_key_file() {
  local method="$1"
  local target="$2"
  local output_file="$3"
  local retries="${4:-$DEFAULT_RETRIES}"
  local retry_delay="${5:-$DEFAULT_RETRY_DELAY}"

  # Validate method
  if ! validate_method "$method"; then
    return 1
  fi

  # Attempt to fetch with retries
  for ((attempt=1; attempt<=retries; attempt++)); do
    local fetch_result=0
    
    case "$method" in
      raw)
        fetch_raw_key "$target" "$output_file" || fetch_result=$?
        ;;
      api)
        fetch_api_key "$target" "$output_file" || fetch_result=$?
        ;;
      ghuser)
        fetch_ghuser_key "$target" "$output_file" || fetch_result=$?
        ;;
    esac

    # If successful, return
    if [[ $fetch_result -eq 0 ]]; then
      return 0
    fi

    # Log retry attempt
    if [[ $attempt -lt $retries ]]; then
      log_warning "Attempt $attempt/$retries failed for method '$method' and target '$target'. Retrying in $retry_delay seconds..."
      sleep "$retry_delay"
    fi
  done

  log_error "All $retries attempts failed for method '$method' and target '$target'"
  return 1
}

# === Self-Update Functions ===

# Download and validate the latest script version
download_latest_script() {
  local latest_url="$1"
  local temp_dir="$2"
  local temp_script="$temp_dir/sync-ssh-keys.sh"
  
  log_info "Downloading latest script from: $latest_url"
  
  if ! curl -fsSL "$latest_url" -o "$temp_script"; then
    log_error "Failed to download the latest script"
    return 1
  fi

  if [[ ! -s "$temp_script" ]]; then
    log_error "Downloaded script is empty"
    return 1
  fi

  # Basic validation - check if it's a bash script
  if ! head -1 "$temp_script" | grep -q "^#!/bin/bash"; then
    log_error "Downloaded file does not appear to be a bash script"
    return 1
  fi

  log_info "Successfully downloaded and validated script"
  return 0
}

# Get the latest release download URL
get_latest_release_url() {
  local repo="$1"
  local api_url="https://api.github.com/repos/$repo/releases/latest"
  
  log_info "Fetching latest release information..." >&2
  
  if ! curl -fsSL "$api_url" | grep "browser_download_url" | grep "sync-ssh-keys.sh" | cut -d '"' -f 4; then
    log_error "Could not determine the latest version URL from GitHub API"
    return 1
  fi
}

# Perform self-update of the script
self_update() {
  local latest_url
  local temp_dir
  local current_script="$SCRIPT_DIR/$SCRIPT_NAME"

  log_info "Starting self-update process..."

  # Get latest release URL
  if ! latest_url=$(get_latest_release_url "$GITHUB_REPO"); then
    log_error "Failed to get latest release URL"
    exit 1
  fi

  if [[ -z "$latest_url" ]]; then
    log_error "Latest release URL is empty"
    exit 1
  fi

  # Create temporary directory
  if ! temp_dir=$(mktemp -d); then
    log_error "Failed to create temporary directory"
    exit 1
  fi

  # Ensure cleanup on exit
  trap 'rm -rf "$temp_dir"' EXIT

  # Download and validate
  if ! download_latest_script "$latest_url" "$temp_dir"; then
    log_error "Failed to download or validate the latest script"
    exit 1
  fi

  # Replace current script
  local temp_script="$temp_dir/sync-ssh-keys.sh"
  if ! chmod +x "$temp_script"; then
    log_error "Failed to make downloaded script executable"
    exit 1
  fi

  if ! mv "$temp_script" "$current_script"; then
    log_error "Failed to replace current script"
    exit 1
  fi

  log_info "Script successfully updated to the latest version"
  exit 0
}

# === User Management Functions ===

# Validate user exists and get user information
validate_user() {
  local username="$1"
  
  if ! id "$username" &>/dev/null; then
    log_warning "User '$username' does not exist. Skipping."
    return 1
  fi
  
  return 0
}

# Get user's home directory safely
get_user_home() {
  local username="$1"
  local user_home
  
  if ! user_home=$(getent passwd "$username" | cut -d: -f6); then
    log_error "Failed to get user information for '$username'"
    return 1
  fi
  
  if [[ -z "$user_home" ]]; then
    log_error "Failed to determine home directory for user '$username'"
    return 1
  fi
  
  echo "$user_home"
}

# Create SSH directory with proper permissions
create_ssh_directory() {
  local username="$1"
  local ssh_dir="$2"
  
  if [[ -d "$ssh_dir" ]]; then
    return 0
  fi
  
  log_info "Creating .ssh directory for user '$username' at $ssh_dir"
  
  if ! mkdir -p "$ssh_dir"; then
    log_error "Failed to create .ssh directory for user '$username'"
    return 1
  fi
  
  if ! chown "$username:$username" "$ssh_dir"; then
    log_error "Failed to set ownership of .ssh directory for user '$username'"
    return 1
  fi
  
  if ! chmod 700 "$ssh_dir"; then
    log_error "Failed to set permissions on .ssh directory for user '$username'"
    return 1
  fi
  
  return 0
}

# Update authorized_keys file with proper permissions
update_authorized_keys() {
  local username="$1"
  local temp_file="$2"
  local auth_keys_file="$3"
  
  # Check if update is needed
  if [[ -f "$auth_keys_file" ]]; then
    # Use a portable comparison method
    if command -v cmp >/dev/null 2>&1; then
      if cmp -s "$temp_file" "$auth_keys_file"; then
        log_info "No changes detected in authorized_keys for user '$username'"
        return 0
      fi
    elif command -v diff >/dev/null 2>&1; then
      if diff -q "$temp_file" "$auth_keys_file" >/dev/null 2>&1; then
        log_info "No changes detected in authorized_keys for user '$username'"
        return 0
      fi
    else
      # Fallback to checksum comparison if neither cmp nor diff is available
      local temp_hash auth_hash
      if command -v sha256sum >/dev/null 2>&1; then
        temp_hash=$(sha256sum "$temp_file" | cut -d' ' -f1)
        auth_hash=$(sha256sum "$auth_keys_file" | cut -d' ' -f1)
      elif command -v md5sum >/dev/null 2>&1; then
        temp_hash=$(md5sum "$temp_file" | cut -d' ' -f1)
        auth_hash=$(md5sum "$auth_keys_file" | cut -d' ' -f1)
      else
        # Last resort: always update if we can't compare
        log_warning "No file comparison tools available. Will always update authorized_keys."
      fi
      
      if [[ -n "$temp_hash" && "$temp_hash" == "$auth_hash" ]]; then
        log_info "No changes detected in authorized_keys for user '$username'"
        return 0
      fi
    fi
  fi
  
  # Perform update
  if [[ ! -f "$auth_keys_file" ]]; then
    log_info "No existing authorized_keys file for user '$username'. Creating a new one."
  else
    log_info "Changes detected in authorized_keys for user '$username'. Updating the file."
  fi
  
  if ! cp "$temp_file" "$auth_keys_file"; then
    log_error "Failed to copy keys to authorized_keys file for user '$username'"
    return 1
  fi
  
  if ! chown "$username:$username" "$auth_keys_file"; then
    log_error "Failed to set ownership of authorized_keys file for user '$username'"
    return 1
  fi
  
  if ! chmod 600 "$auth_keys_file"; then
    log_error "Failed to set permissions on authorized_keys file for user '$username'"
    return 1
  fi
  
  log_info "Updated authorized_keys for user '$username' at $auth_keys_file"
  return 0
}

# Process a single user's SSH keys
process_user_keys() {
  local username="$1"
  local entry="$2"
  local temp_file="$3"
  
  # Parse method and target from entry
  local method="${entry%%:*}"
  local target="${entry#*:}"
  
  # Validate user exists
  if ! validate_user "$username"; then
    return 1
  fi
  
  # Get user home directory
  local user_home
  if ! user_home=$(get_user_home "$username"); then
    return 1
  fi
  
  # Set up paths
  local ssh_dir="$user_home/.ssh"
  local auth_keys_file="$ssh_dir/authorized_keys"
  
  # Create SSH directory if needed
  if ! create_ssh_directory "$username" "$ssh_dir"; then
    return 1
  fi
  
  # Fetch key file
  log_info "Fetching key file for $username from $target (method: $method)"
  if ! fetch_key_file "$method" "$target" "$temp_file"; then
    log_error "Failed to fetch key file for user '$username' from $target after multiple attempts"
    return 1
  fi
  
  # Update authorized_keys file
  if ! update_authorized_keys "$username" "$temp_file" "$auth_keys_file"; then
    return 1
  fi
  
  return 0
}

# === Main Execution ===

# Display usage information
show_usage() {
  cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

SSH Key Sync Script v$SCRIPT_VERSION
Synchronizes SSH authorized_keys files for multiple users from various sources.

OPTIONS:
  --self-update    Update the script to the latest version from GitHub
  --help, -h       Show this help message
  --version, -v    Show version information

For more information, see: https://github.com/$GITHUB_REPO
EOF
}

# Parse command line arguments
parse_arguments() {
  case "${1:-}" in
    --self-update)
      self_update
      ;;
    --help|-h)
      show_usage
      exit 0
      ;;
    --version|-v)
      echo "$SCRIPT_NAME version $SCRIPT_VERSION"
      exit 0
      ;;
    "")
      # No arguments - continue with normal execution
      ;;
    *)
      log_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
}

# Main function
main() {
  temp_files=()
  local failed_users=0
  local processed_users=0
  
  log_info "Starting SSH key synchronization (version $SCRIPT_VERSION)"
  
  # Parse command line arguments
  parse_arguments "$@"
  
  # Source configuration file at global scope
  # shellcheck source=users.conf
  if ! source "$CONFIG_FILE"; then
    log_error "Failed to load configuration file 'users.conf'. Please check the file for syntax errors. Halting execution."
    exit 1
  fi
  
  # Load and validate configuration
  log_info "Loading configuration..."
  load_configuration
  log_info "Configuration loaded successfully"
  
  log_info "Validating configuration..."
  validate_configuration
  log_info "Configuration validated successfully"
  
  # Validate USER_KEYS array has entries
  log_info "Counting users..."
  user_count=0
  if declare -p USER_KEYS &>/dev/null; then
    for username in "${!USER_KEYS[@]}"; do
      log_info "Found user: $username"
      user_count=$((user_count + 1))
      log_info "User count now: $user_count"
    done
  fi
  log_info "Total user count: $user_count"
  
  if [[ $user_count -eq 0 ]]; then
    log_warning "No users defined in USER_KEYS array. Nothing to do."
    exit 0
  fi
  
  # Set up cleanup trap for temporary files
  trap 'rm -f "${temp_files[@]}"' EXIT
  
  # Process each user
  for username in "${!USER_KEYS[@]}"; do
    temp_file=""
    if ! temp_file=$(mktemp); then
      log_error "Failed to create temporary file for user '$username'"
      failed_users=$((failed_users + 1))
      continue
    fi
    
    temp_files+=("$temp_file")
    entry="${USER_KEYS[$username]}"
    
    if process_user_keys "$username" "$entry" "$temp_file"; then
      log_info "Successfully processed user '$username'"
    else
      log_error "Failed to process user '$username'"
      failed_users=$((failed_users + 1))
    fi
    
    processed_users=$((processed_users + 1))
    
    # Clean up temp file immediately
    rm -f "$temp_file"
  done
  
  # Summary
  log_info "Synchronization complete. Processed: $processed_users, Failed: $failed_users"
  
  if [[ $failed_users -gt 0 ]]; then
    exit 1
  fi
}

# Execute main function with all arguments
main "$@"
