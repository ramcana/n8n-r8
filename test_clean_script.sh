#!/bin/bash
# Clean test script without ShellCheck errors

set -e

# Function to print message
print_message() {
    local message="$1"
    echo "Message: $message"
}

# Main execution
main() {
    print_message "This is a clean script"
    echo "All ShellCheck validations should pass"
}

# Run main function
main "$@"