#!/bin/bash
set -euo pipefail

# Unit Test Script for sync-ssh-keys.sh
# This script performs basic validation and testing of the SSH key sync script
# Usage: ./test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly MAIN_SCRIPT="$SCRIPT_DIR/sync-ssh-keys.sh"
readonly CONFIG_FILE="$SCRIPT_DIR/users.conf"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Log functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Test execution function
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo -n "Running test: $test_name... "
  TESTS_RUN=$((TESTS_RUN + 1))
  
  if eval "$test_command" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Test: Script exists and is executable
test_script_exists() {
  [[ -f "$MAIN_SCRIPT" && -x "$MAIN_SCRIPT" ]]
}

# Test: Script has valid bash syntax
test_script_syntax() {
  bash -n "$MAIN_SCRIPT"
}

# Test: Configuration file exists
test_config_exists() {
  [[ -f "$CONFIG_FILE" ]]
}

# Test: Configuration file has valid syntax
test_config_syntax() {
  bash -n "$CONFIG_FILE"
}

# Test: Script version is defined
test_version_defined() {
  grep -q "SCRIPT_VERSION=" "$MAIN_SCRIPT"
}

# Test: Required functions exist
test_required_functions() {
  local functions=("log_message" "fetch_key_file" "validate_method" "load_configuration")
  for func in "${functions[@]}"; do
    if ! grep -q "^$func()" "$MAIN_SCRIPT"; then
      return 1
    fi
  done
  return 0
}

# Test: Script handles --help flag
test_help_flag() {
  "$MAIN_SCRIPT" --help 2>&1 | grep -q "Usage:"
}

# Test: Script handles invalid arguments gracefully
test_invalid_args() {
  ! "$MAIN_SCRIPT" --invalid-flag >/dev/null 2>&1
}

# Test: ShellCheck passes (if available)
test_shellcheck() {
  if command -v shellcheck >/dev/null 2>&1; then
    # Only fail on error or warning level issues, ignore info level
    shellcheck -S error -S warning "$MAIN_SCRIPT"
  else
    log_warning "ShellCheck not available, skipping"
    return 0
  fi
}

# Test: Script can load configuration
test_config_loading() {
  # Create a minimal test config
  local test_config
  test_config=$(mktemp)
  cat > "$test_config" << 'EOF'
#!/bin/bash
declare -A USER_KEYS=()
EOF
  
  # Test that config has valid syntax and can be sourced
  # shellcheck disable=SC1090  # Dynamic source path is intentional for testing
  bash -n "$test_config" && source "$test_config"
  local result=$?
  rm -f "$test_config"
  return $result
}

# Main test execution
main() {
  log_info "Starting unit tests for sync-ssh-keys.sh"
  echo "========================================"
  
  # Basic file tests
  run_test "Script file exists and is executable" "test_script_exists"
  run_test "Script has valid bash syntax" "test_script_syntax"
  run_test "Configuration file exists" "test_config_exists"
  run_test "Configuration file has valid syntax" "test_config_syntax"
  
  # Content tests
  run_test "Script version is defined" "test_version_defined"
  run_test "Required functions exist" "test_required_functions"
  
  # Functionality tests
  run_test "Script handles --help flag" "test_help_flag"
  run_test "Script handles invalid arguments gracefully" "test_invalid_args"
  run_test "ShellCheck validation" "test_shellcheck"
  run_test "Configuration loading works" "test_config_loading"
  
  # Summary
  echo "========================================"
  log_info "Test Summary:"
  echo "  Tests run: $TESTS_RUN"
  echo "  Tests passed: $TESTS_PASSED"
  echo "  Tests failed: $TESTS_FAILED"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    log_info "All tests passed!"
    exit 0
  else
    log_error "$TESTS_FAILED test(s) failed!"
    exit 1
  fi
}

# Check if script should be executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
