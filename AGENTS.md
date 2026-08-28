# AGENTS.md

Guidance for AI coding agents working in `ssh-key-sync`. See also [.github/copilot-instructions.md](.github/copilot-instructions.md) for conventions and the maintenance matrix.

## Project Overview

`ssh-key-sync` is a single-file Bash utility (`sync-ssh-keys.sh`) that synchronizes SSH `authorized_keys` for multiple system users from external sources (public URLs, private GitHub repos via API, or GitHub user key endpoints). Configuration lives in `users.conf`. There is no application server, database, or package manifest — the version is tracked in the `SCRIPT_VERSION` constant inside the script itself (never hardcode it elsewhere; extract it with `awk -F'"' '/SCRIPT_VERSION/ {print $2; exit}' sync-ssh-keys.sh`).

## Repository Structure

```
sync-ssh-keys.sh   # The entire application: logging, config loading, fetch methods, self-update, user/SSH management, main
users.conf          # Externalized configuration (declare -A USER_KEYS=(["user"]="method:target"))
test.sh             # Local test suite (syntax check, function presence, shellcheck if available)
.github/scripts/     # functional-tests.sh, integration-tests.sh — CI test assertions (workflow only provisions fixtures)
TESTING.md          # Testing guide describing CI workflows and local test procedures
README.md           # User-facing docs: install, configuration, usage, automation, troubleshooting, security, FAQ
.github/workflows/  # ci.yml (orchestrator), lint.yml, test.yml, check-version.yml, release.yml
.github/            # copilot-instructions.md, instructions/, skills/, agents/, dependabot.yml
```

## Tech Stack

- **Language**: Bash (4.0+ required for associative arrays), `set -euo pipefail`
- **Runtime deps**: `curl` (HTTP/API calls), `getent` (user lookups), `mktemp` (temp files)
- **No package manager, no build step** — the script runs as-is
- **CI**: GitHub Actions (see CI/CD below)

## Build & Run

There is no build. To run locally:

```bash
chmod +x sync-ssh-keys.sh
sudo ./sync-ssh-keys.sh          # requires root to manage other users' SSH keys
./sync-ssh-keys.sh --help
./sync-ssh-keys.sh --version
./sync-ssh-keys.sh --self-update
```

## Testing

Run before every commit:

```bash
bash -n sync-ssh-keys.sh   # syntax check
./test.sh                  # local test suite
shellcheck sync-ssh-keys.sh  # if installed
```

CI mirrors this in `.github/workflows/lint.yml` (ShellCheck) and `.github/workflows/test.yml` (unit + integration tests using real, temporary Linux users). Integration tests only run on `pull_request` events. Unit tests deliberately avoid executing the main script flow to prevent side effects — they check for function presence via `grep` and validate config parsing in isolation. `test.yml` only provisions CI fixtures (packages, test users); the actual test assertions live in `.github/scripts/functional-tests.sh` and `.github/scripts/integration-tests.sh` — add new test cases there as `test_*` functions, no workflow YAML changes needed.

## Key Patterns and Conventions

- Function name prefixes signal responsibility: `log_*` (utilities), `load_*`/`validate_*` (config), `fetch_*` (key retrieval), `create_*`/`update_*`/`process_*` (user/system management).
- Every function validates its parameters first and returns `1` with a `log_error` call on failure — never silently swallow errors.
- Network calls go through `fetch_key_file`, which owns the retry loop (`DEFAULT_RETRIES=3`, `DEFAULT_RETRY_DELAY=2`); individual `fetch_<method>_key` functions do a single attempt and let the caller retry.
- File writes are atomic: compare before write (`files_are_identical`), write to a temp file, then move into place — this avoids unnecessary `authorized_keys` churn and preserves the retry-safe design.
- Permissions are always set explicitly after writes: `700` for `.ssh`, `600` for `authorized_keys`, ownership via `chown "$username:$user_gid"` where the GID is resolved with `getent`, never guessed.

## Adding a New Fetch Method

The three existing methods (`raw`, `api`, `ghuser`) show the full registration chain a new method must follow — all four steps are required or the method will fail silently or be rejected:

1. Add the method name to the `case` statement in `validate_method()` (sync-ssh-keys.sh).
2. Implement `fetch_<method>_key()` with the same signature as the existing ones: `(target, output_file) -> curl ... -o "$output_file"`.
3. Wire it into the `case` dispatch inside `fetch_key_file()` so retries apply to it automatically.
4. Document it in the README.md "Supported Methods" table and add a corresponding fixture/test case in `.github/scripts/functional-tests.sh`.

## CI/CD

`.github/workflows/ci.yml` is the single required check — it calls `lint.yml`, `test.yml`, and `check-version.yml` (PRs only) as reusable workflows and fails if any of them fail. `check-version.yml` blocks merges that modify `sync-ssh-keys.sh` without bumping `SCRIPT_VERSION` to a value that doesn't already have a matching `vX.Y.Z` git tag. `release.yml` runs on push to `main` when `sync-ssh-keys.sh` or `users.conf` change: it tags the new version and publishes a GitHub Release with auto-generated notes — **this is the project's changelog**; there is no separate `CHANGELOG.md` to keep in sync.

## Common Pitfalls

- Forgetting to bump `SCRIPT_VERSION` when changing `sync-ssh-keys.sh` — CI will reject the PR.
- Adding a fetch method without updating all four places in the chain above.
- Testing against the live `sync-ssh-keys.sh` main flow instead of function-level checks — the CI `test` job intentionally avoids running the script directly for unit tests to prevent unintended filesystem/user side effects; only the `integration-test` job (PRs only) runs it for real, against disposable test users.
- Editing `users.conf` in place during local testing without restoring it — `.github/scripts/functional-tests.sh`/`integration-tests.sh` do `git checkout users.conf` in cleanup; do the same locally.

## Documentation Status

- User-facing docs: [README.md](README.md) (install, config, usage, automation, security, FAQ) and [TESTING.md](TESTING.md) (test infrastructure).
- No dedicated `docs/` site — appropriate for a single-script utility; keep README as the source of truth.
- Changelog: none as a file — GitHub Releases (auto-generated by `release.yml`) serve this purpose.
