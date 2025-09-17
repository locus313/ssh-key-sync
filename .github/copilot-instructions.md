# Copilot Instructions for `ssh-key-sync`

This document provides comprehensive guidance for AI coding agents and contributors working with the `ssh-key-sync` repository. It ensures consistency, quality, and alignment with project standards.

## Project Overview

`ssh-key-sync` is a Bash script-based utility for synchronizing SSH `authorized_keys` files for multiple users. It supports fetching keys from various sources, including public URLs, private GitHub repositories, and GitHub user profiles. The configuration is externalized in a `users.conf` file.

## Key Architecture Components

### Core Script Structure (`sync-ssh-keys.sh`)
The main script follows a modular architecture with distinct functional layers:

- **Utility Functions** (lines 24-41): Timestamped logging functions (`log_message`, `log_error`, `log_warning`, `log_info`)
- **Configuration Management** (lines 43-74): Configuration loading and validation with error handling
- **Fetch Methods** (lines 76-174): Three distinct key fetching strategies with unified retry logic
- **Self-Update System** (lines 176-272): Download, validate, and replace script functionality
- **User Management** (lines 274-443): User validation, SSH directory creation, file permission management
- **Main Execution** (lines 445-614): Command-line parsing, configuration sourcing, and orchestration

### Configuration Architecture (`users.conf`)
Configuration uses Bash associative arrays for user-to-source mapping:
```bash
CONF_GITHUB_TOKEN="token_here"  # Optional GitHub token
declare -A USER_KEYS=(
  ["username"]="method:target"  # method:target pattern
)
```

### Three Key Fetch Methods
1. **`raw`**: Direct HTTP(S) URL fetching (public endpoints)
2. **`api`**: GitHub API with authentication (private repositories) 
3. **`ghuser`**: GitHub user public keys endpoint (`github.com/username.keys`)

## Critical Developer Workflows

### Testing Commands (Essential for Changes)
```bash
# Quick validation - Run before commits
./test.sh

# Manual syntax check
bash -n sync-ssh-keys.sh

# ShellCheck validation (if available)
shellcheck sync-ssh-keys.sh

# Test with actual users (requires root)
sudo ./sync-ssh-keys.sh
```

### CI/CD Pipeline Structure
The project uses a sophisticated multi-workflow CI system:
- **`ci.yml`**: Orchestrates all checks (lint, test, version validation)
- **`test.yml`**: Creates real users, tests all fetch methods, validates error handling
- **`lint.yml`**: ShellCheck static analysis
- **`check-version.yml`**: Ensures version bumps in PRs

### Configuration Testing Pattern
Always test configuration changes with temporary configs:
```bash
cp users.conf users.conf.backup
# Edit users.conf with test values
sudo ./sync-ssh-keys.sh
mv users.conf.backup users.conf
```

### Error Handling Architecture
The script uses a **defensive programming** approach:
- Every function validates parameters and returns meaningful exit codes
- Network operations include retry logic (3 attempts, 2-second delays)
- Temporary file cleanup using `trap` statements
- File comparison before updates to avoid unnecessary writes

### Self-Update Mechanism
The `--self-update` feature demonstrates key patterns:
- GitHub API integration for release information
- Temporary file management with cleanup
- Script validation before replacement
- Atomic replacement to prevent corruption

## Project-Specific Conventions

### Function Organization Pattern
Functions are grouped by responsibility with clear boundaries:
- **Utilities**: Pure functions for logging (prefix: `log_`)
- **Configuration**: Loading and validation (prefix: `load_`, `validate_`)
- **Fetching**: Key retrieval methods (prefix: `fetch_`)
- **User Management**: System operations (prefix: `create_`, `update_`, `process_`)

### Error Handling Style
- Use meaningful exit codes: `return 1` for failures, `return 0` for success
- Log errors before returning: `log_error "message"; return 1`
- Validate parameters at function start: `[[ -z "$param" ]] && { log_error "message"; return 1; }`

### Bash Patterns Used
- `set -euo pipefail` for strict error handling
- Associative arrays for configuration: `declare -A USER_KEYS`
- Here documents for multi-line content in tests
- Parameter expansion for parsing: `${entry%%:*}` and `${entry#*:}`

### File Permission Management
Critical pattern - always set correct permissions:
```bash
chown "$username:$username" "$file"  # User ownership
chmod 700 "$ssh_dir"                 # SSH directory
chmod 600 "$auth_keys_file"          # authorized_keys file
```

## Integration Points

### GitHub API Integration
- **Authentication**: Uses `GITHUB_TOKEN` or `CONF_GITHUB_TOKEN`
- **Headers**: `Authorization: token $GITHUB_TOKEN` and `Accept: application/vnd.github.v3.raw`
- **Rate Limiting**: Automatic retry logic helps with transient failures
- **Private Repos**: Full API endpoint format required: `https://api.github.com/repos/org/repo/contents/path?ref=branch`

### System Dependencies
- **`curl`**: All HTTP operations with `-fsSL` flags (fail silently, show errors, follow redirects, location headers)
- **`getent`**: User information retrieval - more reliable than parsing `/etc/passwd`
- **`mktemp`**: Secure temporary file creation with automatic cleanup
- **File comparison tools**: `cmp` > `diff` > checksum fallback hierarchy

### File System Integration
The script manages SSH infrastructure with specific patterns:
- Creates `.ssh` directories with `700` permissions if missing
- Compares files before updating to avoid unnecessary writes
- Uses atomic operations (temp file → move) for updates
- Maintains proper ownership chain: directory → file → permissions

## Contribution Guidelines

### Pre-Commit Validation
```bash
# Required: Syntax check
bash -n sync-ssh-keys.sh

# Required: Run test suite
./test.sh

# Recommended: Static analysis (if available)
shellcheck sync-ssh-keys.sh
```

### Version Management
- Bump `SCRIPT_VERSION` in PRs (enforced by CI)
- Follow semantic versioning (major.minor.patch)
- Version check workflow prevents duplicate releases

### Code Quality Standards
- All functions must validate input parameters
- Use `log_error` before `return 1` in error conditions
- Maintain consistent indentation (2 spaces)
- Group related functions with clear section comments

### Testing Requirements
- New fetch methods need integration tests in `test.yml`
- Configuration changes require validation tests
- Error conditions must be tested with invalid inputs

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

### Self-Update Feature
- The `--self-update` option fetches the latest version of the script from the GitHub repository.
- Replaces the current script with the downloaded version.
- Ensures the script is always up-to-date with the latest features and fixes.
