# SSH Key Sync

[![Lint Status](https://img.shields.io/github/actions/workflow/status/locus313/ssh-key-sync/lint.yml?style=flat-square&label=lint)](https://github.com/locus313/ssh-key-sync/actions)
[![Test Status](https://img.shields.io/github/actions/workflow/status/locus313/ssh-key-sync/ci.yml?style=flat-square&label=tests)](https://github.com/locus313/ssh-key-sync/actions)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/Version-0.1.4-orange?style=flat-square)](https://github.com/locus313/ssh-key-sync/releases)

⭐ If you like this project, star it on GitHub — it helps a lot!

[Features](#features) • [Getting Started](#getting-started) • [Configuration](#configuration) • [Usage](#usage) • [Examples](#examples) • [Automation](#automation)

A robust Bash script for automating SSH `authorized_keys` synchronization across multiple users from various sources. Perfect for managing SSH access in development environments, CI/CD pipelines, and production systems.

## Features

- **Multiple Key Sources**: Fetch SSH keys from public URLs, private GitHub repositories, or GitHub user profiles
- **Retry Logic**: Built-in retry mechanism with configurable delays for handling network failures
- **Safe Updates**: Only modifies `authorized_keys` when remote content has actually changed
- **Comprehensive Logging**: Detailed timestamped logs for monitoring and debugging
- **Self-Updating**: Automatically update to the latest version from the GitHub repository
- **Configuration-Driven**: External configuration file for easy management
- **Error Handling**: Robust error handling with graceful fallbacks
- **Multi-User Support**: Manage SSH keys for multiple system users simultaneously

## Getting Started

### Prerequisites

- Bash 4.0 or later
- `curl` for HTTP requests
- `getent` for user information (typically available on Linux systems)
- GitHub token (only required for private repository access)

### Quick Start

1. **Download the script**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh -o sync-ssh-keys.sh
   chmod +x sync-ssh-keys.sh
   ```

2. **Download the configuration template**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/users.conf -o users.conf
   ```

3. **Configure your users** by editing `users.conf`:
   ```bash
   nano users.conf
   ```

4. **Run the script**:
   ```bash
   ./sync-ssh-keys.sh
   ```

## Configuration

Configuration is managed through the `users.conf` file, which defines users and their SSH key sources.

### Configuration Format

```bash
# Optional: GitHub token for private repository access
CONF_GITHUB_TOKEN="your_github_token_here"

# User key mapping
declare -A USER_KEYS=(
  ["username"]="method:target"
)
```

### Supported Methods

| Method | Description | Example |
|--------|-------------|---------|
| `raw` | Fetch from public URL | `raw:https://example.com/keys.txt` |
| `api` | Fetch from private GitHub repo via API | `api:https://api.github.com/repos/org/repo/contents/keys/user.keys?ref=main` |
| `ghuser` | Fetch public keys from GitHub user | `ghuser:username` |

### Example Configuration

```bash
#!/bin/bash

# GitHub token for API access (optional)
CONF_GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# User key definitions
declare -A USER_KEYS=(
  # Fetch from public URL
  ["ubuntu"]="raw:https://example.com/ssh-keys/ubuntu.authorized_keys"
  
  # Fetch from private GitHub repository
  ["devuser"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/devuser.authorized_keys?ref=main"
  
  # Fetch public keys from GitHub user
  ["alice"]="ghuser:alice-github-username"
  ["bob"]="ghuser:bob-github-username"
)
```

## Usage

### Command Line Options

```bash
./sync-ssh-keys.sh [OPTIONS]

OPTIONS:
  --self-update    Update the script to the latest version from GitHub
  --help, -h       Show help message
  --version, -v    Show version information
```

### Environment Variables

- `GITHUB_TOKEN`: GitHub personal access token (overrides `CONF_GITHUB_TOKEN`)

### Basic Usage

```bash
# Run synchronization
./sync-ssh-keys.sh

# Update script to latest version
./sync-ssh-keys.sh --self-update

# Show help
./sync-ssh-keys.sh --help
```

## Examples

### Adding New Users

1. **Add a user with GitHub public keys**:
   ```bash
   # Edit users.conf
   ["newuser"]="ghuser:github-username"
   ```

2. **Add a user with keys from a private repository**:
   ```bash
   ["secureuser"]="api:https://api.github.com/repos/company/ssh-keys/contents/users/secureuser.keys?ref=main"
   ```

3. **Add a user with keys from a public URL**:
   ```bash
   ["webuser"]="raw:https://company.com/keys/webuser.authorized_keys"
   ```

### GitHub Token Setup

For private repositories, you need a GitHub personal access token:

1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with `repo` scope
3. Add it to your configuration:
   ```bash
   CONF_GITHUB_TOKEN="your_token_here"
   ```

### Multiple Key Sources

You can configure users with different key sources:

```bash
declare -A USER_KEYS=(
  ["prod-user"]="api:https://api.github.com/repos/company/prod-keys/contents/prod-user.keys?ref=main"
  ["dev-user"]="ghuser:dev-github-username"
  ["external-user"]="raw:https://partner.com/keys/external-user.keys"
)
```

## Automation

### Cron Setup

Add to root's crontab for automated synchronization:

```bash
# Edit crontab
sudo crontab -e

# Add entry (sync every 15 minutes)
*/15 * * * * /path/to/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1
```

### Systemd Timer

Create a systemd service and timer:

1. **Create service file** `/etc/systemd/system/ssh-key-sync.service`:
   ```ini
   [Unit]
   Description=SSH Key Synchronization
   Wants=ssh-key-sync.timer

   [Service]
   Type=oneshot
   ExecStart=/path/to/sync-ssh-keys.sh
   User=root

   [Install]
   WantedBy=multi-user.target
   ```

2. **Create timer file** `/etc/systemd/system/ssh-key-sync.timer`:
   ```ini
   [Unit]
   Description=Run SSH Key Sync every 15 minutes
   Requires=ssh-key-sync.service

   [Timer]
   OnCalendar=*:0/15
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

3. **Enable and start**:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable ssh-key-sync.timer
   sudo systemctl start ssh-key-sync.timer
   ```

### CI/CD Integration

Use in CI/CD pipelines for automated SSH access management:

```yaml
# GitHub Actions example
- name: Sync SSH Keys
  run: |
    curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh | bash -s
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Troubleshooting

### Common Issues

**Permission denied errors**:
```bash
# Ensure script is executable
chmod +x sync-ssh-keys.sh

# Run with appropriate privileges
sudo ./sync-ssh-keys.sh
```

**GitHub API rate limits**:
- Use authenticated requests with a GitHub token
- Consider reducing sync frequency

**Network timeouts**:
- Script includes automatic retry logic (3 attempts by default)
- Check network connectivity and firewall settings

### Logging

The script provides detailed logging with timestamps:

```
2025-08-29 12:00:00: Starting SSH key synchronization (version 0.1.0)
2025-08-29 12:00:01: Fetching key file for user 'ubuntu' from https://example.com/keys.txt (method: raw)
2025-08-29 12:00:02: Successfully processed user 'ubuntu'
2025-08-29 12:00:02: Synchronization complete. Processed: 1, Failed: 0
```

## Testing

The project includes comprehensive testing to ensure reliability:

### Automated Testing
- **GitHub Actions CI**: Runs on all pull requests and pushes
- **Lint Checks**: ShellCheck validation for code quality
- **Unit Tests**: Configuration validation and function testing
- **Integration Tests**: Real environment testing with user creation

### Running Tests Locally
```bash
# Quick validation
./test.sh

# Manual syntax check
bash -n sync-ssh-keys.sh

# With ShellCheck (if installed)
shellcheck sync-ssh-keys.sh
```

### CI Status
[![Test Status](https://img.shields.io/github/actions/workflow/status/locus313/ssh-key-sync/ci.yml?style=flat-square&label=tests)](https://github.com/locus313/ssh-key-sync/actions)

For detailed testing information, see [TESTING.md](TESTING.md).

## Security Considerations

- Store GitHub tokens securely and rotate them regularly
- Use least-privilege access for GitHub tokens (only `repo` scope if needed)
- Monitor logs for failed authentication attempts
- Validate SSH key sources before adding them to configuration
- Consider using private repositories for sensitive key storage

## FAQ

**Q: Can I use this script with GitLab or other Git providers?**
A: Currently, the script supports GitHub's API. For other providers, use the `raw` method with direct URLs to key files.

**Q: What happens if a user doesn't exist on the system?**
A: The script will log a warning and skip that user, continuing with the next user in the configuration.

**Q: How often should I run the synchronization?**
A: This depends on your security requirements. Common intervals are 15 minutes for development environments and 1 hour for production systems.
