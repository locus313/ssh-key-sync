# SSH Key Sync Script

This Bash script pulls `authorized_keys` files from remote URLs and updates SSH access for multiple local users.

## 🔧 Features

- Pull-based (ideal for cron or systemd timer)
- Supports multiple users
- Works with:
  - ✅ Public URLs (method: `raw`)
  - ✅ Private GitHub repositories via GitHub API (method: `api`, requires token)
  - ✅ GitHub user public keys (method: `ghuser`)
- Safe: Only updates keys if they’ve changed
- Logs activity per user

## ⚙️ Configuration

User configuration is stored in a separate `users.conf` file in the same directory as the script.  
Edit `users.conf` to define users and their key sources.  
Each entry uses the format:  
`["username"]="method:url"`

- **raw:** Fetches directly from a public URL.
- **api:** Fetches from a private GitHub repo using the GitHub API (requires `GITHUB_TOKEN` environment variable).
- **ghuser:** Fetches public keys from a GitHub user's profile (provide the GitHub username after the colon).

**Example `users.conf`:**
```bash
declare -A USER_KEYS=(
  ["ubuntu"]="raw:https://example.com/ssh-keys/ubuntu.authorized_keys"
  ["devuser"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/devuser.authorized_keys?ref=main"
  ["alice"]="ghuser:alice-github-username"
)
```

## Usage

1. Edit the `users.conf` file to define users and their key URLs or GitHub usernames.
2. If using the `api` method, export your GitHub token:
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```
3. Make sure the script is executable:
   ```bash
   chmod +x sync-ssh-keys.sh
   ```
4. Add to root's crontab:
   ```cron
   */15 * * * * /usr/local/bin/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1
   ```

## Implementation Notes

- The script sources `users.conf` for configuration.
- Uses a helper function `fetch_key_file` to fetch keys using the appropriate method.
- Only updates a user's `authorized_keys` if the remote file has changed.
- Logs all actions with timestamps.
