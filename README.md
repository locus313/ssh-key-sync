# SSH Key Sync Script

This Bash script pulls `authorized_keys` files from remote URLs and updates SSH access for multiple local users.

## Features

- Pull-based, no Git required
- Supports multiple users
- Designed for use with cron or systemd

## Usage

1. Edit the `USER_KEYS` array in `sync-ssh-keys.sh` to define users and their key URLs.
2. Add to root's crontab:

```cron
*/15 * * * * /usr/local/bin/sync-ssh-keys.sh >> /var/log/ssh-key-sync.log 2>&1
```

