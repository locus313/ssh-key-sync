#!/bin/bash
# Functional tests for sync-ssh-keys.sh, run by .github/workflows/test.yml's `test` job.
#
# Assumes: script is executable, testuser1/testuser2/testuser3 system users exist,
# and the job runs with sudo access. To add a new test, write a test_* function and
# add a run_test line at the bottom — no workflow.yml changes needed.
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
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -n "Running test: $name... "
  if "$@"; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${RED}FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

test_missing_config_rejected() {
  mv users.conf users.conf.backup
  local out
  out=$(sudo "$MAIN_SCRIPT" 2>&1)
  mv users.conf.backup users.conf
  echo "$out" | grep -q "Failed to load configuration file 'users.conf'"
}

test_config_loading() {
  cat >users.conf <<'EOF'
#!/bin/bash
CONF_GITHUB_TOKEN=""
declare -A USER_KEYS=(
  ["testuser1"]="ghuser:locus313"
  ["testuser2"]="raw:https://github.com/locus313.keys"
)
EOF
  bash -c 'source users.conf && declare -p USER_KEYS >/dev/null'
}

test_invalid_method_rejected() {
  cat >users.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=(
  ["testuser1"]="invalid:test"
)
EOF
  sudo "$MAIN_SCRIPT" 2>&1 | grep -q "Unsupported method 'invalid'"
}

test_required_functions_present() {
  grep -q "^log_message()" "$MAIN_SCRIPT" &&
    grep -q "^fetch_key_file()" "$MAIN_SCRIPT" &&
    grep -q "^validate_method()" "$MAIN_SCRIPT" &&
    grep -q "^load_configuration()" "$MAIN_SCRIPT"
}

test_empty_user_array() {
  cat >users.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=()
EOF
  "$MAIN_SCRIPT" 2>&1 | grep -q "No users defined in USER_KEYS array"
}

test_ghuser_endpoint_reachable() {
  curl -fsSL "https://github.com/locus313.keys" | head -2 >/dev/null
}

test_version_extractable() {
  local version
  version=$(awk -F'"' '/SCRIPT_VERSION/ {print $2; exit}' "$MAIN_SCRIPT")
  [[ -n "$version" ]]
}

test_self_update_functions_present() {
  grep -q "self_update()" "$MAIN_SCRIPT" &&
    grep -q "get_latest_release_url" "$MAIN_SCRIPT" &&
    grep -q "download_latest_script" "$MAIN_SCRIPT"
}

test_error_config_syntax_valid() {
  cat >/tmp/test-errors.conf <<'EOF'
#!/bin/bash
declare -A USER_KEYS=(
  ["nonexistentuser"]="ghuser:nonexistentuser12345"
  ["testuser1"]="raw:https://invalid-url-that-does-not-exist.example.com/keys"
)
EOF
  bash -n /tmp/test-errors.conf
}

test_log_functions_present() {
  grep -q "log_message()" "$MAIN_SCRIPT" &&
    grep -q "log_error()" "$MAIN_SCRIPT" &&
    grep -q "log_warning()" "$MAIN_SCRIPT" &&
    grep -q "log_info()" "$MAIN_SCRIPT"
}

cleanup() {
  git checkout users.conf 2>/dev/null || true
  rm -f /tmp/test-errors.conf
}
trap cleanup EXIT

run_test "Configuration file validation"      test_missing_config_rejected
run_test "Configuration loading"              test_config_loading
run_test "Invalid method handling"            test_invalid_method_rejected
run_test "Required functions present"         test_required_functions_present
run_test "Empty user array handling"          test_empty_user_array
run_test "GitHub user key endpoint reachable" test_ghuser_endpoint_reachable
run_test "Script version extraction"          test_version_extractable
run_test "Self-update functions present"      test_self_update_functions_present
run_test "Error handling config syntax"       test_error_config_syntax_valid
run_test "Log functions present"              test_log_functions_present

echo "========================================"
echo "Tests run: $TESTS_RUN, failed: $TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
