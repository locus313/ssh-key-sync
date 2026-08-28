#!/bin/bash
# Integration tests for sync-ssh-keys.sh, run by .github/workflows/test.yml's
# `integration-test` job (pull_request events only).
#
# Assumes: script is executable, `integrationuser` and `symlinkuser` system users
# exist, and the job runs with sudo access. To add a new test, write a test_*
# function and add a run_test line at the bottom — no workflow.yml changes needed.
set -u

cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1
readonly MAIN_SCRIPT="./sync-ssh-keys.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
TESTS_RUN=0
TESTS_FAILED=0

run_test() {
  local name="$1"
  shift
  echo "--- $name ---"
  TESTS_RUN=$((TESTS_RUN + 1))
  if "$@"; then
    echo -e "${GREEN}PASS${NC}: $name"
  else
    echo -e "${RED}FAIL${NC}: $name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_sync_creates_authorized_keys() {
  cat >users.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=(
  ["integrationuser"]="ghuser:locus313"
)
EOF
  sudo "$MAIN_SCRIPT" || return 1
  sudo test -f /home/integrationuser/.ssh/authorized_keys
}

test_file_permissions_correct() {
  [[ "$(sudo stat -c '%a' /home/integrationuser/.ssh)" == "700" ]] &&
    [[ "$(sudo stat -c '%a' /home/integrationuser/.ssh/authorized_keys)" == "600" ]]
}

test_reject_symlink_ssh_directory() {
  local canary
  canary="ssh-key-sync-canary-$(date +%s)-$$"
  sudo mkdir -p /root/.ssh
  sudo chmod 700 /root/.ssh
  echo "$canary" | sudo tee /root/.ssh/authorized_keys >/dev/null
  sudo chmod 600 /root/.ssh/authorized_keys

  sudo -u symlinkuser rm -rf /home/symlinkuser/.ssh
  sudo -u symlinkuser ln -s /root/.ssh /home/symlinkuser/.ssh

  cat >users.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=(
  ["symlinkuser"]="ghuser:locus313"
)
EOF

  local out rc
  out=$(sudo "$MAIN_SCRIPT" 2>&1)
  rc=$?
  echo "$out"

  [[ $rc -ne 0 ]] &&
    echo "$out" | grep -q "Refusing symlink .ssh directory" &&
    sudo grep -qx "$canary" /root/.ssh/authorized_keys
}

test_reject_symlink_authorized_keys() {
  local canary
  canary="ssh-key-sync-canary-keys-$(date +%s)-$$"
  echo "$canary" | sudo tee /root/.ssh/authorized_keys >/dev/null
  sudo chmod 600 /root/.ssh/authorized_keys

  # Real .ssh dir owned by user, but authorized_keys points at root's file.
  sudo rm -rf /home/symlinkuser/.ssh
  sudo -u symlinkuser mkdir -m 700 /home/symlinkuser/.ssh
  sudo -u symlinkuser ln -s /root/.ssh/authorized_keys /home/symlinkuser/.ssh/authorized_keys

  cat >users.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=(
  ["symlinkuser"]="ghuser:locus313"
)
EOF

  local out rc
  out=$(sudo "$MAIN_SCRIPT" 2>&1)
  rc=$?
  echo "$out"

  [[ $rc -ne 0 ]] &&
    echo "$out" | grep -q "Refusing to write through symlink authorized_keys" &&
    sudo grep -qx "$canary" /root/.ssh/authorized_keys &&
    sudo test -L /home/symlinkuser/.ssh/authorized_keys
}

cleanup() {
  git checkout users.conf 2>/dev/null || true
}
trap cleanup EXIT

run_test "Sync creates authorized_keys"           test_sync_creates_authorized_keys
run_test "File permissions are correct (700/600)" test_file_permissions_correct
run_test "Reject symlink .ssh directory"          test_reject_symlink_ssh_directory
run_test "Reject symlink authorized_keys"         test_reject_symlink_authorized_keys

echo "========================================"
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
