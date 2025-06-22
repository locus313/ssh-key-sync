# SSH Key Sync Script

This Bash script pulls `authorized_keys` files from remote URLs and updates SSH access for multiple local users.

## 🔧 Features

- Pull-based (ideal for cron or systemd timer)
- Supports multiple users
- Works with:
  - ✅ Public URLs (method: `raw`)
  - ✅ Private GitHub repositories via GitHub API (method: `api`, requires token)
- Safe: Only updates keys if they’ve changed
- Logs activity per user

## ⚙️ Configuration

Edit the `USER_KEYS` associative array in `sync-ssh-keys.sh` to define users and their key sources.  
Each entry uses the format:  
`["username"]="method:url"`

- **raw:** Fetches directly from a public URL.
- **api:** Fetches from a private GitHub repo using the GitHub API (requires `GITHUB_TOKEN` environment variable).

**Example:**
```bash
declare -A USER_KEYS=(
  ["ubuntu"]="raw:https://example.com/ssh-keys/ubuntu.authorized_keys"
  ["devuser"]="api:https://api.github.com/repos/yourorg/ssh-keys/contents/keys/devuser.authorized_keys?ref=main"
)
```

## Usage

1. Edit the `USER_KEYS` array in `sync-ssh-keys.sh` to define users and their key URLs.
2. If using the `api` method, export your GitHub token:
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```
3. Add to root's crontab:

```cron
*/15 * * * * /usr/local/bin/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1
```

## Implementation Notes

- The script uses a helper function `fetch_key_file` to fetch keys using the appropriate method.
- Only updates a user's `authorized_keys` if the remote file has changed.
- Logs all actions with timestamps.
