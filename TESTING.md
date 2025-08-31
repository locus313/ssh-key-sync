# Testing Guide for ssh-key-sync

This document describes the testing infrastructure and procedures for the `ssh-key-sync` project.

## Overview

The project includes comprehensive testing to ensure reliability and prevent regressions:

1. **Automated CI/CD Testing** - GitHub Actions workflows
2. **Local Unit Testing** - Standalone test script
3. **Linting and Static Analysis** - ShellCheck validation
4. **Integration Testing** - Real environment testing

## GitHub Actions Workflows

### Main CI Workflow (`.github/workflows/ci.yml`)
The primary CI workflow that orchestrates all testing:
- Runs on pull requests and pushes to main
- Coordinates lint, test, and version check workflows
- Provides final pass/fail status

### Test Workflow (`.github/workflows/test.yml`)
Comprehensive functional testing:
- **Unit Tests**: Configuration validation, error handling, function presence
- **Integration Tests**: Real user creation and SSH key synchronization
- **Mock Tests**: Network endpoint validation without external dependencies
- **Error Condition Tests**: Invalid configurations and edge cases

### Lint Workflow (`.github/workflows/lint.yml`)
Static code analysis:
- ShellCheck for shell script best practices
- Syntax validation
- Security and style checks

### Version Check Workflow (`.github/workflows/check-version.yml`)
Ensures proper versioning:
- Validates that SCRIPT_VERSION changes in PRs
- Prevents duplicate version tags
- Maintains version consistency

## Local Testing

### Quick Test Script (`test.sh`)
Run local validation tests:
```bash
./test.sh
```

This script performs:
- File existence and permission checks
- Bash syntax validation
- Function presence verification
- Basic functionality tests
- ShellCheck integration (if available)

### Manual Testing
For development and debugging:

1. **Syntax Check**:
   ```bash
   bash -n sync-ssh-keys.sh
   ```

2. **Help Output**:
   ```bash
   ./sync-ssh-keys.sh --help
   ```

3. **Dry Run with Test Config**:
   ```bash
   # Create test configuration
   cp users.conf users.conf.backup
   # Edit users.conf with test values
   ./sync-ssh-keys.sh
   # Restore original
   mv users.conf.backup users.conf
   ```

## Test Coverage

### Configuration Testing
- ✅ Missing configuration file handling
- ✅ Invalid syntax detection
- ✅ Empty user array handling
- ✅ Invalid method validation
- ✅ GitHub token validation

### Functionality Testing
- ✅ User existence validation
- ✅ SSH directory creation
- ✅ File permission management
- ✅ Key fetching methods (raw, api, ghuser)
- ✅ Retry logic for failed operations
- ✅ Error handling and logging

### Integration Testing
- ✅ Real user creation and management
- ✅ Actual SSH key synchronization
- ✅ File system permission verification
- ✅ Network connectivity tests

### Security Testing
- ✅ File permission enforcement (700 for .ssh, 600 for authorized_keys)
- ✅ User ownership validation
- ✅ Input sanitization
- ✅ Secure temporary file handling

## Test Data and Fixtures

### Test Users
The CI creates temporary test users:
- `testuser1`, `testuser2`, `testuser3` for unit tests
- `integrationuser` for integration tests

### Test Configurations
Various test configurations are used:
- Valid configurations with public GitHub users
- Invalid method configurations
- Empty user arrays
- Error-inducing configurations

### Mock Endpoints
Tests use real but safe endpoints:
- `https://github.com/octocat.keys` - GitHub's mascot user
- GitHub API endpoints for public repositories

## Running Tests Locally

### Prerequisites
- Bash 4.0+ (for associative arrays)
- `curl` for network operations
- `shellcheck` (optional, for linting)
- `sudo` access (for integration tests)

### Full Test Suite
```bash
# Run unit tests
./test.sh

# Run linting (if shellcheck is available)
shellcheck sync-ssh-keys.sh

# Test with actual configuration
cp users.conf users.conf.backup
# Edit users.conf with your test configuration
./sync-ssh-keys.sh
mv users.conf.backup users.conf
```

### CI Simulation
To simulate the CI environment locally:
```bash
# Install shellcheck
sudo apt-get install shellcheck  # Ubuntu/Debian
# or
brew install shellcheck          # macOS

# Run the same checks as CI
bash -n sync-ssh-keys.sh         # Syntax check
shellcheck sync-ssh-keys.sh      # Linting
./test.sh                        # Unit tests
```

## Debugging Test Failures

### Local Test Failures
1. Check script syntax: `bash -n sync-ssh-keys.sh`
2. Verify file permissions: `ls -la sync-ssh-keys.sh test.sh`
3. Check dependencies: `which curl bash`
4. Review test output for specific failures

### CI Test Failures
1. Check the GitHub Actions logs for detailed error messages
2. Look for specific test step failures
3. Verify that any new code follows existing patterns
4. Ensure configuration changes are valid

### Common Issues
- **Permission denied**: Script files not executable
- **Syntax errors**: Bash syntax issues in script or config
- **Network failures**: External endpoints unavailable
- **User conflicts**: Test users already exist

## Contributing Test Cases

When adding new features or fixing bugs:

1. **Add unit tests** to `test.yml` workflow
2. **Update the local test script** if needed
3. **Test edge cases** and error conditions
4. **Ensure backward compatibility**
5. **Document test scenarios** in pull requests

### Test Case Guidelines
- Test both success and failure paths
- Include boundary conditions
- Verify error messages are helpful
- Ensure cleanup after tests
- Use realistic but safe test data

## Performance Considerations

Tests are designed to be:
- **Fast**: Most tests complete in seconds
- **Reliable**: Use stable external endpoints
- **Isolated**: Don't interfere with each other
- **Repeatable**: Can be run multiple times safely

The integration tests may take longer due to:
- User creation/deletion operations
- Network requests to GitHub
- File system operations

## Security Considerations

Tests follow security best practices:
- Use public endpoints only
- No real secrets in test configurations
- Proper cleanup of temporary users and files
- File permission validation
- Input sanitization testing
