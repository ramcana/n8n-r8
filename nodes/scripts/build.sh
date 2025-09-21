#!/bin/bash

# N8N Custom Nodes Build Script
# This script builds custom N8N nodes for development and production
set -euo pipefail
# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODES_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$NODES_DIR")"
# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}
error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}
info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}
check_prerequisites() {
    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)
    if [[ $major_version -lt 18 ]]; then
        error "Node.js version $node_version is not supported. Please install Node.js 18 or higher."
        exit 1
    fi
    # Check if npm is installed
    if ! command -v npm >/dev/null 2>&1; then
        error "npm is not installed. Please install npm first."
        exit 1
    fi
    log "Prerequisites check passed (Node.js $node_version)"
}
# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    cd "$NODES_DIR"
    if [[ ! -f "package.json" ]]; then
        error "package.json not found in $NODES_DIR"
        exit 1
    fi
    # Install dependencies
    npm install
    log "Dependencies installed successfully"
}
# Clean build artifacts
clean_build() {
    log "Cleaning build artifacts..."
    # Remove dist directory
    rm -rf dist/
    # Remove TypeScript build info
    rm -f tsconfig.tsbuildinfo
    # Remove coverage reports
    rm -rf coverage/
    # Remove npm cache
    npm cache clean --force 2>/dev/null || true
    log "Build artifacts cleaned"
}
# Run linting
run_lint() {
    local fix_issues="$1"
    log "Running ESLint..."
    if [[ "$fix_issues" == "true" ]]; then
        npm run lint:fix
        log "Linting completed with auto-fix"
    else
        npm run lint
        log "Linting completed"
    fi
}
# Format code
format_code() {
    log "Formatting code with Prettier..."
    npm run format
    log "Code formatting completed"
}
# Run tests
run_tests() {
    local coverage="$1"
    log "Running tests..."
    if [[ "$coverage" == "true" ]]; then
        npm run test:coverage
        log "Tests completed with coverage report"
    else
        npm run test
        log "Tests completed"
    fi
}
# Build nodes
build_nodes() {
    local production="$1"
    local verbose="$2"
    log "Building custom N8N nodes..."
    # Set environment variables
    if [[ "$production" == "true" ]]; then
        export NODE_ENV=production
        info "Building for production"
    else
        export NODE_ENV=development
        info "Building for development"
    fi
    # Run TypeScript compilation
    if [[ "$verbose" == "true" ]]; then
        npm run compile -- --verbose
    else
        npm run compile
    fi
    # Verify build output
    if [[ ! -d "dist" ]]; then
        error "Build failed - dist directory not created"
        return 1
    fi
    # Count built files
    local node_files
    node_files=$(find dist -name "*.node.js" | wc -l)
    local credential_files
    credential_files=$(find dist -name "*.credential.js" | wc -l)
    log "Build completed successfully"
    info "Built $node_files node(s) and $credential_files credential(s)"
    # List built files
    if [[ "$verbose" == "true" ]]; then
        echo ""
        info "Built files:"
        find dist -name "*.js" | sed 's/^/  /'
    fi
# Watch for changes
watch_build() {
    log "Starting watch mode..."
    # Start TypeScript compiler in watch mode
    npm run compile:watch
}
# Validate all
validate_all() {
    local skip_tests="$1"
    local skip_lint="$2"
    log "Running validation checks..."
    local validation_failed=false
    # Run linting
    if [[ "$skip_lint" != "true" ]]; then
        if ! run_lint false; then
            validation_failed=true
        fi
    fi
    # Check formatting
    if ! npm run format:check; then
        error "Code formatting check failed"
        validation_failed=true
    fi
    # Run tests
    if [[ "$skip_tests" != "true" ]]; then
        if ! run_tests false; then
            validation_failed=true
        fi
    fi
    # Try to build
    if ! build_nodes false false; then
        validation_failed=true
    fi
    if [[ "$validation_failed" == "true" ]]; then
        error "Validation failed"
        return 1
    fi
    log "All validation checks passed"
}
# Package nodes for distribution
package_nodes() {
    log "Packaging nodes for distribution..."
    # Ensure build is up to date
    build_nodes true false
    # Create package
    npm pack
    local package_file
    package_file=$(ls -t *.tgz | head -n1)
    log "Package created: $package_file"
    # Move to project root for easy access
    mv "$package_file" "$PROJECT_DIR/"
    info "Package moved to project root: $PROJECT_DIR/$package_file"
}
# Show build info
show_build_info() {
    log "Build Information:"
    echo "  Project: $(npm pkg get name | tr -d '"')"
    echo "  Version: $(npm pkg get version | tr -d '"')"
    echo "  Node.js: $(node --version)"
    echo "  npm: $(npm --version)"
    echo "  TypeScript: $(npx tsc --version)"
    if [[ -d "dist" ]]; then
        local node_count
        node_count=$(find dist -name "*.node.js" | wc -l)
        local credential_count
        credential_count=$(find dist -name "*.credential.js" | wc -l)
        echo "  Built Nodes: $node_count"
        echo "  Built Credentials: $credential_count"
        echo "  Build Size: $(du -sh dist | cut -f1)"
    else
        echo "  Build Status: Not built"
    fi
}
# Main function
main() {
    local command="build"
    local verbose=false
    local production=false
    local skip_tests=false
    local skip_lint=false
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --production)
                production=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-lint)
                skip_lint=true
                shift
                ;;
            build|watch|clean|lint|format|test|validate|install|package|info)
                command="$1"
                shift
                ;;
            -*)
                error "Unknown option: $1"
                exit 1
                ;;
            *)
                error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
    log "N8N Custom Nodes Build System"
    log "=============================="
    # Change to nodes directory
    cd "$NODES_DIR"
    # Execute command
    case "$command" in
        "build")
            check_prerequisites
            build_nodes "$production" "$verbose"
            ;;
        "watch")
            check_prerequisites
            watch_build
            ;;
        "clean")
            clean_build
            ;;
        "lint")
            run_lint true
            ;;
        "format")
            format_code
            ;;
        "test")
            run_tests true
            ;;
        "validate")
            validate_all "$skip_tests" "$skip_lint"
            ;;
        "install")
            check_prerequisites
            install_dependencies
            ;;
        "package")
            package_nodes
            ;;
        "info")
            show_build_info
            ;;
        *)
            error "Unknown command: $command"
            usage
            ;;
    esac
}
# Execute main
main "$@"
