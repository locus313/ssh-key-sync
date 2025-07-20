# Copilot Instructions for `ssh-key-sync`

This document provides comprehensive guidance for AI coding agents and contributors working with the `ssh-key-sync` repository. It ensures consistency, quality, and alignment with project standards.

## Project Overview

`ssh-key-sync` is a Bash script-based utility for synchronizing SSH `authorized_keys` files for multiple users. It supports fetching keys from various sources, including public URLs, private GitHub repositories, and GitHub user profiles. The configuration is externalized in a `users.conf` file.

## Key Components

### Scripts
- **`sync-ssh-keys.sh`**: The main script that performs the synchronization. It includes:
  - Support for multiple fetch methods (`raw`, `api`, `ghuser`).
  - Logging and error handling.
  - Configuration loading from `users.conf`.
  - A helper function `fetch_key_file` to handle key retrieval logic with retries for failed operations.

### Configuration
- **`users.conf`**: Defines users and their key sources. Example structure:
  ```bash
  CONF_GITHUB_TOKEN="your_github_token_here"

  declare -A USER_KEYS=(
    ["ubuntu"]="raw:https://example.com/ssh-keys/ubuntu.authorized_keys"
    ["devuser"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/devuser.authorized_keys?ref=main"
    ["alice"]="ghuser:alice-github-username"
  )
  ```

## Developer Workflows

### Running the Script
1. Ensure `sync-ssh-keys.sh` is executable:
   ```bash
   chmod +x sync-ssh-keys.sh
   ```
2. Run the script manually:
   ```bash
   ./sync-ssh-keys.sh
   ```

### Configuration
- Edit `users.conf` to define users and their key sources.
- If using the `api` method, ensure `CONF_GITHUB_TOKEN` is set in `users.conf` or export `GITHUB_TOKEN` in the environment.

### Automating with Cron
- Add the script to root's crontab:
  ```cron
  */15 * * * * /path/to/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1
  ```

### Logging
- Logs are printed to the console with timestamps.
- Example log message:
  ```
  2025-07-20 12:00:00: Fetching key file for user 'ubuntu' from https://example.com/ssh-keys/ubuntu.authorized_keys (method: raw)
  ```

## Coding Conventions

- Use meaningful variable and function names.
- Follow the existing code style in `sync-ssh-keys.sh`.
- Add comments for complex logic.
- Use environment variables for sensitive data (e.g., `GITHUB_TOKEN`).
- Ensure temporary files are cleaned up using `trap`.

## Integration Points

### GitHub API
- Used for fetching keys from private repositories (`api` method).
- Requires a GitHub token (`GITHUB_TOKEN` or `CONF_GITHUB_TOKEN`).

### System Integration
- The script ensures the `.ssh` directory and `authorized_keys` file exist for each user.
- Updates file permissions and ownership as needed.

## Contribution Guidelines

- Include a clear description of changes in pull requests.
- Reference related issues.
- Ensure the script passes linting (e.g., using `shellcheck`).
- Test changes locally before submission.

## Examples

### Adding a New User
1. Add the user to `users.conf`:
   ```bash
   ["newuser"]="ghuser:newuser-github-username"
   ```
2. Run the script to sync keys:
   ```bash
   ./sync-ssh-keys.sh
   ```

### Fetch Methods
- **`raw`**: Fetches keys from a public URL.
- **`api`**: Fetches keys from a private GitHub repository using the GitHub API.
- **`ghuser`**: Fetches public keys from a GitHub user's profile.

### Enhanced Error Handling
- The `fetch_key_file` function includes a retry mechanism for failed fetch operations.
- By default, it retries up to 3 times with a 2-second delay between attempts.
- Logs detailed error messages for each failed attempt and skips the user if all retries fail.
