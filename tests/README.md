# N8N-R8 Testing Framework

This directory contains comprehensive tests for the N8N-R8 project, including unit tests, integration tests, and validation scripts.

## Test Structure

```
tests/
├── unit/                    # Unit tests for individual scripts
│   ├── test_backup.sh      # Backup script tests
│   ├── test_restore.sh     # Restore script tests
│   ├── test_monitoring.sh  # Monitoring script tests
│   └── test_utils.sh       # Utility function tests
├── integration/             # Integration tests for complete workflows
│   ├── test_deployment.sh  # End-to-end deployment tests
│   ├── test_monitoring_stack.sh  # Full monitoring stack tests
│   ├── test_custom_nodes.sh      # Custom nodes integration tests
│   └── test_proxy_configs.sh     # Proxy configuration tests
├── validation/              # Environment and configuration validation
│   ├── validate_environment.sh   # System requirements validation
│   ├── validate_config.sh        # Configuration file validation
│   ├── validate_security.sh      # Security configuration validation
│   └── validate_performance.sh   # Performance baseline validation
├── fixtures/                # Test data and configuration files
│   ├── test_configs/       # Test configuration files
│   ├── test_data/          # Sample test data
│   └── mock_services/      # Mock service configurations
├── helpers/                 # Test helper functions and utilities
│   ├── test_helpers.sh     # Common test functions
│   ├── docker_helpers.sh   # Docker testing utilities
│   └── assertion_helpers.sh # Test assertion functions
├── reports/                 # Test reports and coverage
├── run_tests.sh            # Main test runner script
├── test_config.sh          # Test configuration settings
└── README.md               # This file
```

## Running Tests

### All Tests
```bash
# Run all tests
./tests/run_tests.sh

# Run with verbose output
./tests/run_tests.sh --verbose

# Run with coverage reporting
./tests/run_tests.sh --coverage
```

### Specific Test Categories
```bash
# Unit tests only
./tests/run_tests.sh --unit

# Integration tests only
./tests/run_tests.sh --integration

# Validation tests only
./tests/run_tests.sh --validation
```

### Individual Test Files
```bash
# Run specific test file
./tests/unit/test_backup.sh

# Run with debug output
./tests/unit/test_backup.sh --debug
```

## Test Configuration

Edit `test_config.sh` to customize test settings:

```bash
# Test environment settings
TEST_TIMEOUT=300
TEST_PARALLEL=true
TEST_CLEANUP=true

# Docker test settings
TEST_DOCKER_NETWORK="n8n-test"
TEST_DOCKER_PREFIX="test_"

# Coverage settings
COVERAGE_THRESHOLD=80
COVERAGE_REPORT_FORMAT="html"
```

## Writing Tests

### Test Function Naming
- Unit tests: `test_function_name()`
- Integration tests: `test_integration_scenario()`
- Validation tests: `test_validate_requirement()`

### Test Structure
```bash
#!/bin/bash
source "$(dirname "$0")/../helpers/test_helpers.sh"

setup() {
    # Test setup code
}

teardown() {
    # Test cleanup code
}

test_example_function() {
    # Arrange
    local input="test_input"
    
    # Act
    local result=$(example_function "$input")
    
    # Assert
    assert_equals "expected_output" "$result"
}

# Run tests
run_test_suite
```

## Continuous Integration

Tests are designed to run in CI/CD environments with:
- Automated test execution on pull requests
- Coverage reporting
- Performance regression detection
- Security vulnerability scanning

## Test Reports

Test results are saved in `reports/` directory:
- `test_results.xml` - JUnit format test results
- `coverage.html` - Code coverage report
- `performance.json` - Performance benchmark results
- `security_scan.json` - Security scan results
