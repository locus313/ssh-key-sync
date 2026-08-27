## Description

<!-- What does this PR change and why? -->

## Changes

<!-- List the key changes -->

-

## How to Test

```bash
bash -n sync-ssh-keys.sh
./test.sh
shellcheck sync-ssh-keys.sh
```

## Checklist

- [ ] `bash -n sync-ssh-keys.sh` passes
- [ ] `./test.sh` passes locally
- [ ] `shellcheck sync-ssh-keys.sh` has no new warnings
- [ ] Bumped `SCRIPT_VERSION` in `sync-ssh-keys.sh` if the script changed (see [AGENTS.md](../AGENTS.md#common-pitfalls))
- [ ] Updated `README.md` / `TESTING.md` if configuration format, fetch methods, or workflows changed
- [ ] Added/updated a test fixture in `.github/workflows/test.yml` for new behavior
