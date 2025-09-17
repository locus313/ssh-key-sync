# SSH Key Sync

[![CI Status](https://img.shields.io/github/actions/workflow/status/locus313/ssh-key-sync/ci.yml?style=flat-square&label=CI)](https://github.com/locus313/ssh-key-sync/actions)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.0+-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/Version-0.1.5-orange?style=flat-square)](https://github.com/locus313/ssh-key-sync/releases)

*Synchronize SSH authorized_keys for multiple users from various sources*

⭐ If you like this project, star it on GitHub — it helps a lot!

[Features](#features) • [Getting Started](#getting-started) • [Configuration](#configuration) • [Usage](#usage) • [Examples](#examples) • [Automation](#automation) • [Testing](#testing)

A robust and secure Bash script for automating SSH `authorized_keys` synchronization across multiple users from various sources. Perfect for managing SSH access in development environments, CI/CD pipelines, and production systems with enterprise-grade reliability.

## Features

- **Multi-Source Support** - Fetch SSH keys from public URLs, private GitHub repositories, or GitHub user profiles
- **Enterprise-Grade Reliability** - Built-in retry mechanism with configurable delays for network resilience  
- **Atomic Operations** - Safe file updates with comparison checks to prevent unnecessary changes
- **Comprehensive Audit Trail** - Detailed timestamped logs for monitoring, debugging, and compliance
- **Self-Maintenance** - Automatic updates to the latest version from GitHub repository
- **Configuration-as-Code** - External configuration file for version control and team collaboration
- **Defensive Programming** - Robust error handling with graceful fallbacks and validation
- **Multi-User Architecture** - Concurrent SSH key management for multiple system users
- **Security-First Design** - Proper file permissions, user validation, and secure temporary file handling

## Getting Started

### Prerequisites

- **Bash 4.0+** - Required for associative arrays support
- **curl** - For HTTP operations and API communication
- **getent** - User information retrieval (standard on most Linux distributions)
- **GitHub Token** - Only required for accessing private repositories

> [!TIP]
> You can test the script locally without any external dependencies by using the `raw` method with publicly accessible SSH key files.

### Quick Start

1. **Download the script and configuration**:
   ```bash
   # Get the latest release
   curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh -o sync-ssh-keys.sh
   curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/users.conf -o users.conf
   chmod +x sync-ssh-keys.sh
   ```

2. **Configure your users and key sources**:
   ```bash
   # Edit the configuration file
   nano users.conf
   
   # Example configuration
   declare -A USER_KEYS=(
     ["alice"]="ghuser:alice-github"
     ["bob"]="raw:https://example.com/bob.keys"
   )
   ```

3. **Run the synchronization**:
   ```bash
   # Test the configuration first
   sudo ./sync-ssh-keys.sh
   
   # Check the logs for successful synchronization
   ```

4. **Verify the setup**:
   ```bash
   # Check that keys were properly synchronized
   sudo cat /home/alice/.ssh/authorized_keys
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

| Method | Description | Use Case | Authentication |
|--------|-------------|----------|----------------|
| `raw` | Direct HTTP(S) URL | Public key repositories, CDNs | None |
| `api` | GitHub API endpoint | Private repositories, enterprise | GitHub Token |
| `ghuser` | GitHub user profile | Individual developer keys | None |

> [!NOTE]
> The `ghuser` method fetches public keys from `https://github.com/username.keys`, which is a built-in GitHub feature for accessing any user's public SSH keys.

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

### Team Management

Configure SSH access for a development team with mixed requirements:

```bash
declare -A USER_KEYS=(
  # DevOps team with enterprise private keys
  ["devops-lead"]="api:https://api.github.com/repos/company/ssh-keys/contents/team/devops-lead.keys?ref=main"
  ["sre-admin"]="api:https://api.github.com/repos/company/ssh-keys/contents/team/sre-admin.keys?ref=main"
  
  # Developers using personal GitHub keys
  ["alice"]="ghuser:alice-dev"
  ["bob"]="ghuser:bob-coder"
  ["charlie"]="ghuser:charlie-ops"
  
  # Service accounts and automation
  ["ci-deploy"]="raw:https://cdn.company.com/ci-keys/deploy-bot.keys"
  ["backup-service"]="raw:https://secure.company.com/service-keys/backup.authorized_keys"
)
```

### Staging vs Production

Different configurations for different environments:

```bash
# staging.conf - More permissive for development
declare -A USER_KEYS=(
  ["dev-alice"]="ghuser:alice-personal"
  ["dev-bob"]="ghuser:bob-personal"
  ["staging-deploy"]="raw:https://staging-keys.company.com/deploy.keys"
)

# production.conf - Strict enterprise keys only
declare -A USER_KEYS=(
  ["prod-alice"]="api:https://api.github.com/repos/company/prod-keys/contents/alice.keys?ref=main"
  ["prod-deploy"]="api:https://api.github.com/repos/company/prod-keys/contents/deploy.keys?ref=main"
)
```

### Multi-Region Deployment

Sync keys across multiple regions with different sources:

```bash
declare -A USER_KEYS=(
  # Global admin access
  ["global-admin"]="api:https://api.github.com/repos/company/global-keys/contents/admin.keys?ref=main"
  
  # Region-specific access
  ["us-east-ops"]="raw:https://us-east.company.com/ops-keys/authorized_keys"
  ["eu-west-ops"]="raw:https://eu-west.company.com/ops-keys/authorized_keys"
  ["asia-ops"]="raw:https://asia.company.com/ops-keys/authorized_keys"
)
```

### GitHub Token Setup

For accessing private repositories, you'll need a GitHub Personal Access Token:

1. **Generate a token**:
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Select scopes: `repo` (for private repository access)
   - Set an appropriate expiration date

2. **Configure the token**:
   ```bash
   # Option 1: In configuration file
   CONF_GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   
   # Option 2: Environment variable
   export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
   sudo -E ./sync-ssh-keys.sh
   ```

3. **Secure storage**:
   ```bash
   # Restrict configuration file permissions
   chmod 600 users.conf
   
   # Or use a secrets management system
   GITHUB_TOKEN=$(vault kv get -field=token secret/github/ssh-sync)
   ```

> [!IMPORTANT]
> **Security Best Practice**: Use tokens with minimal required permissions and rotate them regularly. For organizations, consider using GitHub Apps instead of personal access tokens.

## Automation

### Production Deployment with Cron

Set up automated synchronization for production environments:

```bash
# Edit root crontab
sudo crontab -e

# Sync every 15 minutes with logging
*/15 * * * * /opt/ssh-key-sync/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1

# Daily summary report (optional)
0 9 * * * grep "$(date +%Y-%m-%d)" /var/log/ssh-key-sync.log | mail -s "SSH Key Sync Daily Report" admin@company.com
```

### Modern Systemd Integration

Create a robust systemd service with automatic restart and monitoring:

1. **Create the service** `/etc/systemd/system/ssh-key-sync.service`:
   ```ini
   [Unit]
   Description=SSH Key Synchronization Service
   Documentation=https://github.com/locus313/ssh-key-sync
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=oneshot
   ExecStart=/opt/ssh-key-sync/sync-ssh-keys.sh
   User=root
   Group=root
   StandardOutput=journal
   StandardError=journal
   
   # Security settings
   NoNewPrivileges=true
   ProtectSystem=strict
   ProtectHome=true
   ReadWritePaths=/home /root
   
   [Install]
   WantedBy=multi-user.target
   ```

2. **Create the timer** `/etc/systemd/system/ssh-key-sync.timer`:
   ```ini
   [Unit]
   Description=Run SSH Key Sync every 10 minutes
   Documentation=https://github.com/locus313/ssh-key-sync
   Requires=ssh-key-sync.service

   [Timer]
   OnBootSec=5min
   OnUnitActiveSec=10min
   RandomizedDelaySec=2min
   Persistent=true

   [Install]
   WantedBy=timers.target
   ```

3. **Deploy and monitor**:
   ```bash
   # Install and start
   sudo systemctl daemon-reload
   sudo systemctl enable ssh-key-sync.timer
   sudo systemctl start ssh-key-sync.timer
   
   # Monitor status
   sudo systemctl status ssh-key-sync.timer
   sudo journalctl -u ssh-key-sync.service -f
   ```

### CI/CD Pipeline Integration

Integrate with popular CI/CD platforms for automated deployment:

#### GitHub Actions
```yaml
name: Deploy and Sync SSH Keys
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy application
        run: ./deploy.sh
        
      - name: Sync SSH keys on target servers
        run: |
          # Download and run ssh-key-sync
          curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh | \
          ssh -o StrictHostKeyChecking=no deploy@${{ secrets.SERVER_HOST }} 'cat > sync-ssh-keys.sh && chmod +x sync-ssh-keys.sh && sudo ./sync-ssh-keys.sh'
        env:
          GITHUB_TOKEN: ${{ secrets.SSH_SYNC_TOKEN }}
```

#### GitLab CI
```yaml
stages:
  - deploy
  - post-deploy

sync-ssh-keys:
  stage: post-deploy
  script:
    - apt-get update && apt-get install -y curl
    - curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh -o sync-ssh-keys.sh
    - chmod +x sync-ssh-keys.sh
    - ./sync-ssh-keys.sh
  variables:
    GITHUB_TOKEN: $CI_SSH_SYNC_TOKEN
  only:
    - main
```

#### Jenkins Pipeline
```groovy
pipeline {
    agent any
    
    environment {
        GITHUB_TOKEN = credentials('ssh-sync-github-token')
    }
    
    stages {
        stage('Deploy') {
            steps {
                sh './deploy.sh'
            }
        }
        
        stage('Sync SSH Keys') {
            steps {
                sh '''
                    curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/sync-ssh-keys.sh -o sync-ssh-keys.sh
                    chmod +x sync-ssh-keys.sh
                    sudo ./sync-ssh-keys.sh
                '''
            }
        }
    }
    
    post {
        always {
            sh 'rm -f sync-ssh-keys.sh'
        }
    }
}
```

## Troubleshooting

### Common Issues and Solutions

<details>
<summary><strong>Permission denied errors</strong></summary>

```bash
# Ensure script is executable
chmod +x sync-ssh-keys.sh

# Run with appropriate privileges (required for managing other users' SSH keys)
sudo ./sync-ssh-keys.sh

# Check file ownership and permissions
ls -la sync-ssh-keys.sh users.conf
```
</details>

<details>
<summary><strong>GitHub API rate limits</strong></summary>

```bash
# Use authenticated requests (increases rate limit from 60 to 5000 per hour)
export GITHUB_TOKEN="your_token_here"

# Monitor your rate limit
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit

# Consider reducing sync frequency for high-volume usage
```
</details>

<details>
<summary><strong>Network connectivity issues</strong></summary>

The script includes automatic retry logic (3 attempts by default), but you can troubleshoot:

```bash
# Test direct connectivity
curl -I https://github.com
curl -I https://api.github.com

# Check DNS resolution
nslookup github.com

# Test with verbose curl output
curl -v https://github.com/username.keys
```
</details>

<details>
<summary><strong>User validation failures</strong></summary>

```bash
# Check if user exists
id username

# Create user if needed
sudo useradd -m username

# Verify user home directory
getent passwd username
```
</details>

<details>
<summary><strong>Configuration syntax errors</strong></summary>

```bash
# Validate Bash syntax
bash -n users.conf

# Check for common issues
# - Missing quotes around array values
# - Incorrect associative array syntax
# - Typos in method names (raw, api, ghuser)
```
</details>

### Debug Mode

Enable detailed debugging information:

```bash
# Run with bash debug mode
bash -x sync-ssh-keys.sh

# Or modify the script temporarily
# Add 'set -x' at the top of sync-ssh-keys.sh
```

### Log Analysis

Understanding log output:

```bash
# Successful execution logs
2025-09-17 12:00:00: Starting SSH key synchronization (version 0.1.5)
2025-09-17 12:00:01: Loading configuration...
2025-09-17 12:00:01: Found 3 user(s) to process
2025-09-17 12:00:02: Fetching key file for alice from https://github.com/alice.keys (method: ghuser)
2025-09-17 12:00:03: Updated authorized_keys for user 'alice' at /home/alice/.ssh/authorized_keys
2025-09-17 12:00:03: Successfully processed user 'alice'
2025-09-17 12:00:04: Synchronization complete. Processed: 3, Failed: 0

# Error patterns to watch for
ERROR: User 'nonexistent' does not exist. Skipping.
ERROR: GITHUB_TOKEN is required for API access
ERROR: Failed to fetch key file for user 'alice' from https://invalid-url after multiple attempts
WARNING: No changes detected in authorized_keys for user 'bob'
```

## Testing

The project includes comprehensive testing infrastructure to ensure reliability and prevent regressions:

### Automated Testing Pipeline

[![CI Status](https://img.shields.io/github/actions/workflow/status/locus313/ssh-key-sync/ci.yml?style=flat-square&label=CI)](https://github.com/locus313/ssh-key-sync/actions)

The project uses a **centralized CI workflow** that orchestrates all testing and validation:

- **Lint Check** - ShellCheck static analysis for code quality and best practices
- **Version Check** - Ensures version bumps in pull requests for proper release management
- **Integration Tests** - Real user creation, SSH key synchronization, and error handling validation
- **Multi-Environment Testing** - Validation across different Linux distributions
- **Security Focus** - Proper permissions, file handling, and authentication validation

> [!NOTE]
> **Workflow Architecture**: The CI workflow calls individual test workflows (`lint.yml`, `test.yml`, `check-version.yml`) as reusable workflows, preventing duplicate runs while maintaining organized test separation.

### Running Tests Locally

```bash
# Quick validation suite
./test.sh

# Manual syntax validation
bash -n sync-ssh-keys.sh

# With ShellCheck (recommended)
shellcheck sync-ssh-keys.sh

# Test with dry-run mode (if implemented)
./sync-ssh-keys.sh --dry-run
```

### Test Coverage

The test suite validates:
- ✅ Configuration file parsing and validation
- ✅ User existence and permission checks  
- ✅ Network connectivity and retry logic
- ✅ File operations and atomic updates
- ✅ Error handling and edge cases
- ✅ GitHub API integration
- ✅ Security permissions and ownership

### Development Testing

For contributors and advanced users:

```bash
# Create isolated test environment
docker run -it --rm ubuntu:22.04 bash

# Install dependencies and test
apt update && apt install -y curl bash
curl -fsSL https://raw.githubusercontent.com/locus313/ssh-key-sync/main/test.sh | bash
```

> [!NOTE]
> For detailed testing procedures and guidelines, see [TESTING.md](TESTING.md).

## Security Considerations

> [!IMPORTANT]
> **Production Security Checklist**
> - [ ] Store GitHub tokens securely and rotate them regularly (every 90 days recommended)
> - [ ] Use least-privilege tokens with only required scopes (`repo` for private repos)
> - [ ] Monitor logs for failed authentication attempts and unusual activity
> - [ ] Validate SSH key sources and ownership before adding to configuration
> - [ ] Use private repositories for sensitive key storage, never public ones
> - [ ] Implement proper backup and recovery procedures for SSH key configuration
> - [ ] Regular audit of user access and key validity

### Token Security

```bash
# Use environment variables instead of hardcoding tokens
export GITHUB_TOKEN="$(vault kv get -field=token secret/github/ssh-sync)"

# Restrict configuration file permissions
chmod 600 users.conf
chown root:root users.conf

# Consider using GitHub Apps for organization-wide deployments
# They provide better security and audit trails than personal access tokens
```

### Network Security

```bash
# Validate SSL certificates (default behavior)
# The script uses curl with strict SSL validation

# For air-gapped environments, consider using local mirrors
declare -A USER_KEYS=(
  ["user"]="raw:https://internal-mirror.company.com/keys/user.authorized_keys"
)

# Monitor network traffic if required
tcpdump -i any host github.com
```

### File System Security

The script automatically implements security best practices:

- **SSH Directory**: `700` permissions (owner access only)
- **Authorized Keys**: `600` permissions (owner read/write only)  
- **Proper Ownership**: All files owned by the target user
- **Atomic Operations**: Temporary files with secure cleanup
- **Input Validation**: Validates all user inputs and file paths

### Audit and Compliance

```bash
# Enable comprehensive logging for compliance
sudo ./sync-ssh-keys.sh 2>&1 | tee -a /var/log/ssh-key-sync-audit.log

# Log rotation for long-term storage
cat > /etc/logrotate.d/ssh-key-sync << EOF
/var/log/ssh-key-sync*.log {
    daily
    rotate 365
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}
EOF
```

## FAQ

<details>
<summary><strong>Can I use this script with GitLab, Bitbucket, or other Git providers?</strong></summary>

Currently, the script has built-in support for GitHub's API and public key endpoints. For other providers:

- **GitLab**: Use the `raw` method with GitLab's raw file URLs
- **Bitbucket**: Use the `raw` method with Bitbucket's raw file URLs  
- **Azure DevOps**: Use the `raw` method with Azure DevOps file URLs
- **Custom Git servers**: Use the `raw` method with direct HTTPS URLs

Example:
```bash
["user"]="raw:https://gitlab.com/username/ssh-keys/-/raw/main/user.keys"
```
</details>

<details>
<summary><strong>What happens if a user doesn't exist on the system?</strong></summary>

The script validates user existence before processing and will:
1. Log a warning message
2. Skip that user entirely  
3. Continue processing other users
4. Report the failure in the final summary

This ensures the script doesn't fail completely due to one missing user.
</details>

<details>
<summary><strong>How often should I run the synchronization?</strong></summary>

Recommended frequencies based on environment:
- **Development**: Every 15-30 minutes for rapid iteration
- **Staging**: Every 1-2 hours for testing stability
- **Production**: Every 4-6 hours for security balance
- **High-security environments**: Every 1 hour with audit logging

Consider your team's SSH key rotation frequency and security requirements.
</details>

<details>
<summary><strong>Can I customize the retry logic and timeouts?</strong></summary>

Yes, the script uses configurable constants that you can modify:

```bash
# Edit these variables in sync-ssh-keys.sh
readonly DEFAULT_RETRIES=3
readonly DEFAULT_RETRY_DELAY=2

# Or pass them as parameters (if you modify the script)
fetch_key_file "$method" "$target" "$temp_file" 5 3  # 5 retries, 3 second delay
```
</details>

<details>
<summary><strong>Is there a dry-run mode to test configuration?</strong></summary>

While not currently implemented, you can safely test by:

1. **Configuration validation**: `bash -n users.conf`
2. **Syntax check**: `bash -n sync-ssh-keys.sh`  
3. **Test environment**: Run on a test system with test users
4. **Verbose logging**: Use `bash -x sync-ssh-keys.sh` for detailed output

A dry-run mode is planned for future releases.
</details>

<details>
<summary><strong>How do I handle SSH key rotation?</strong></summary>

The script automatically handles key rotation:

1. **Update the source** (GitHub keys, file URLs, etc.)
2. **Run the sync** - the script detects changes automatically
3. **Verify the update** - check the logs for confirmation

The script only updates files when content actually changes, making it safe to run frequently.
</details>

<details>
<summary><strong>Can I exclude certain keys or add filtering?</strong></summary>

Currently, the script syncs all keys from the configured source. For filtering:

1. **Source-level filtering**: Maintain filtered key files at the source
2. **Multiple sources**: Create separate endpoints for different key sets
3. **Custom scripts**: Pipe through additional filtering if needed

Advanced filtering features may be added in future versions.
</details>
