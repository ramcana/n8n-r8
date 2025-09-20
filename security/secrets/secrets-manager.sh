#!/bin/bash

# N8N-R8 Secrets Manager
# Comprehensive secrets management with HashiCorp Vault integration
set -euo pipefail
# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
SECURITY_DIR="$(dirname "$SCRIPT_DIR")"
# Source configuration
    # shellcheck source=/dev/null
source "$SECURITY_DIR/security-config.env" 2>/dev/null || true
# Default configuration
VAULT_ENABLED=${VAULT_ENABLED:-false}
VAULT_URL=${VAULT_URL:-"http://localhost:8200"}
VAULT_TOKEN_FILE=${VAULT_TOKEN_FILE:-"$SECURITY_DIR/secrets/.vault_token"}
VAULT_SECRETS_PATH=${VAULT_SECRETS_PATH:-"secret/n8n-r8"}
ENCRYPTION_KEY_FILE=${ENCRYPTION_KEY_FILE:-"$SECURITY_DIR/secrets/.encryption_key"}
ENCRYPTED_ENV_FILE=${ENCRYPTED_ENV_FILE:-"$PROJECT_ROOT/.env.encrypted"}
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
# Help function
show_help() {
    cat << EOF
N8N-R8 Secrets Manager
USAGE:
    $0 [COMMAND] [OPTIONS]
COMMANDS:
    init                Initialize secrets management
    encrypt             Encrypt environment file
    decrypt             Decrypt environment file
    store               Store secret in vault
    retrieve            Retrieve secret from vault
    rotate              Rotate secrets
    backup              Backup secrets
    restore             Restore secrets
    status              Show secrets status
    clean               Clean up secrets
OPTIONS:
    --vault-url URL     Vault server URL
    --vault-token TOKEN Vault authentication token
    --key-file FILE     Encryption key file
    --env-file FILE     Environment file to process
    --secret-name NAME  Name of the secret
    --secret-value VAL  Value of the secret
    --backup-file FILE  Backup file path
    --force             Force operation without confirmation
    --help              Show this help message
EXAMPLES:
    $0 init                                    # Initialize secrets management
    $0 encrypt --env-file .env                 # Encrypt environment file
    $0 store --secret-name db_password --secret-value "secure123"
    $0 retrieve --secret-name db_password      # Retrieve secret from vault
    $0 rotate                                  # Rotate all secrets
    $0 backup --backup-file secrets.backup    # Backup secrets
EOF
# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    if [[ "$VAULT_ENABLED" == "true" ]] && ! command -v vault &> /dev/null; then
        missing_deps+=("vault")
    fi
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        exit 1
    fi
# Generate encryption key
generate_encryption_key() {
    local key_file="$1"
    log_info "Generating encryption key: $key_file"
    # Create secrets directory if it doesn't exist
    mkdir -p "$(dirname "$key_file")"
    # Generate 256-bit encryption key
    openssl rand -hex 32 > "$key_file"
    chmod 600 "$key_file"
    log_success "Encryption key generated"
# Initialize secrets management
init_secrets() {
    log_info "Initializing secrets management"
    # Create secrets directory
    mkdir -p "$SECURITY_DIR/secrets"
    chmod 700 "$SECURITY_DIR/secrets"
    # Generate encryption key if it doesn't exist
    if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
        generate_encryption_key "$ENCRYPTION_KEY_FILE"
    fi
    # Initialize Vault if enabled
    if [[ "$VAULT_ENABLED" == "true" ]]; then
        init_vault
    fi
    # Create initial secrets configuration
    create_secrets_config
    log_success "Secrets management initialized"
# Initialize Vault
init_vault() {
    log_info "Initializing HashiCorp Vault"
    # Check if Vault is accessible
    if ! curl -s "$VAULT_URL/v1/sys/health" > /dev/null; then
        log_warning "Vault server not accessible at $VAULT_URL"
        log_info "Please start Vault server or update VAULT_URL"
        return 1
    # Check if Vault is initialized
    local vault_status
    vault_status=$(curl -s "$VAULT_URL/v1/sys/init" | jq -r '.initialized')
    if [[ "$vault_status" != "true" ]]; then
        log_info "Vault not initialized, initializing now..."
        
        # Initialize Vault
        local init_response
        init_response=$(curl -s -X PUT "$VAULT_URL/v1/sys/init" \
            -d '{"secret_shares": 1, "secret_threshold": 1}')
        # Extract root token and unseal key
        local root_token
        root_token=$(echo "$init_response" | jq -r '.root_token')
        local unseal_key
        unseal_key=$(echo "$init_response" | jq -r '.keys[0]')
        # Save tokens securely
        echo "$root_token" > "$VAULT_TOKEN_FILE"
        chmod 600 "$VAULT_TOKEN_FILE"
        echo "$unseal_key" > "$SECURITY_DIR/secrets/.vault_unseal_key"
        chmod 600 "$SECURITY_DIR/secrets/.vault_unseal_key"
        # Unseal Vault
        curl -s -X PUT "$VAULT_URL/v1/sys/unseal" \
            -d "{\"key\": \"$unseal_key\"}" > /dev/null
        log_success "Vault initialized and unsealed"
    else
        log_info "Vault already initialized"
    # Enable KV secrets engine if not already enabled
    if [[ -f "$VAULT_TOKEN_FILE" ]]; then
        local vault_token
        vault_token=$(cat "$VAULT_TOKEN_FILE")
        curl -s -X POST "$VAULT_URL/v1/sys/mounts/secret" \
            -H "X-Vault-Token: $vault_token" \
            -d '{"type": "kv", "options": {"version": "2"}}' > /dev/null || true
        log_success "Vault KV engine enabled"
    fi
# Create secrets configuration
create_secrets_config() {
    local config_file="$SECURITY_DIR/secrets/secrets-config.json"
    cat > "$config_file" << 'EOF'
{
    "version": "1.0",
    "encryption": {
        "algorithm": "AES-256-CBC",
        "key_file": "/path/to/encryption/key"
    },
    "vault": {
        "enabled": false,
        "url": "http://localhost:8200",
        "token_file": "/path/to/token",
        "secrets_path": "secret/n8n-r8"
    },
    "secrets": {
        "n8n_basic_auth_password": {
            "description": "N8N basic authentication password",
            "rotation_days": 90,
            "complexity": "high"
        },
        "postgres_password": {
            "description": "PostgreSQL database password",
            "rotation_days": 60,
            "complexity": "medium"
        },
        "redis_password": {
            "description": "Redis cache password",
            "rotation_days": 60,
            "complexity": "medium"
        },
        "n8n_encryption_key": {
            "description": "N8N encryption key",
            "rotation_days": 180,
            "complexity": "high"
        },
        "n8n_jwt_secret": {
            "description": "N8N JWT secret",
            "rotation_days": 30,
            "complexity": "high"
        }
    }
}
EOF
    # Update with actual values
    sed -i "s|/path/to/encryption/key|$ENCRYPTION_KEY_FILE|g" "$config_file"
    sed -i "s|/path/to/token|$VAULT_TOKEN_FILE|g" "$config_file"
    sed -i "s|false|$VAULT_ENABLED|g" "$config_file"
    chmod 600 "$config_file"
    log_success "Secrets configuration created"
# Encrypt environment file
encrypt_env_file() {
    local env_file="${1:-$PROJECT_ROOT/.env}"
    local encrypted_file="${2:-$ENCRYPTED_ENV_FILE}"
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        return 1
    fi
    if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
        log_error "Encryption key not found: $ENCRYPTION_KEY_FILE"
        return 1
    fi
    log_info "Encrypting environment file: $env_file"
    # Read encryption key
    local encryption_key
    encryption_key=$(cat "$ENCRYPTION_KEY_FILE")
    # Encrypt file using AES-256-CBC
    openssl enc -aes-256-cbc -salt -in "$env_file" -out "$encrypted_file" -k "$encryption_key"
    # Set secure permissions
    chmod 600 "$encrypted_file"
    log_success "Environment file encrypted: $encrypted_file"
# Decrypt environment file
decrypt_env_file() {
    local encrypted_file="${1:-$ENCRYPTED_ENV_FILE}"
    local env_file="${2:-$PROJECT_ROOT/.env.decrypted}"
    if [[ ! -f "$encrypted_file" ]]; then
        log_error "Encrypted file not found: $encrypted_file"
        return 1
    fi
    if [[ ! -f "$ENCRYPTION_KEY_FILE" ]]; then
        log_error "Encryption key not found: $ENCRYPTION_KEY_FILE"
        return 1
    fi
    log_info "Decrypting environment file: $encrypted_file"
    # Decrypt file using AES-256-CBC
    openssl enc -aes-256-cbc -d -salt -in "$encrypted_file" -out "$env_file" -k "$encryption_key"
    chmod 600 "$env_file"
    log_success "Environment file decrypted: $env_file"
# Store secret in Vault
store_secret() {
    local secret_name="$1"
    local secret_value="$2"
    if [[ "$VAULT_ENABLED" != "true" ]]; then
        log_error "Vault is not enabled"
        return 1
    fi
    if [[ ! -f "$VAULT_TOKEN_FILE" ]]; then
        log_error "Vault token file not found: $VAULT_TOKEN_FILE"
        return 1
    fi
    log_info "Storing secret in Vault: $secret_name"
    local vault_token
    vault_token=$(cat "$VAULT_TOKEN_FILE")
    # Store secret in Vault
    local response
    response=$(curl -s -X POST "$VAULT_URL/v1/$VAULT_SECRETS_PATH/data/$secret_name" \
        -H "X-Vault-Token: $vault_token" \
        -d "{\"data\": {\"value\": \"$secret_value\", \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}")
    if echo "$response" | jq -e '.errors' > /dev/null 2>&1; then
        log_error "Failed to store secret: $(echo "$response" | jq -r '.errors[]')"
        return 1
    fi
    log_success "Secret stored in Vault: $secret_name"
# Retrieve secret from Vault
retrieve_secret() {
    local secret_name="$1"
    if [[ "$VAULT_ENABLED" != "true" ]]; then
        log_error "Vault is not enabled"
        return 1
    fi
    if [[ ! -f "$VAULT_TOKEN_FILE" ]]; then
        log_error "Vault token file not found: $VAULT_TOKEN_FILE"
        return 1
    fi
    log_info "Retrieving secret from Vault: $secret_name"
    local vault_token
    vault_token=$(cat "$VAULT_TOKEN_FILE")
    # Retrieve secret from Vault
    local response
    response=$(curl -s -X GET "$VAULT_URL/v1/$VAULT_SECRETS_PATH/data/$secret_name" \
        -H "X-Vault-Token: $vault_token")
    if echo "$response" | jq -e '.errors' > /dev/null 2>&1; then
        log_error "Failed to retrieve secret: $(echo "$response" | jq -r '.errors[]')"
        return 1
    fi
    # Extract secret value
    local secret_value
    secret_value=$(echo "$response" | jq -r '.data.data.value')
    if [[ "$secret_value" == "null" ]]; then
        log_error "Secret not found: $secret_name"
        return 1
    fi
    echo "$secret_value"
# Generate secure password
generate_password() {
    local length="${1:-32}"
    local complexity="${2:-high}"
    case "$complexity" in
        low)
            openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
            ;;
        medium)
            # Medium complexity: mixed case, numbers
            openssl rand -base64 32 | tr -d "=+/" | head -c "$length"
            ;;
        high)
            # High complexity: mixed case, numbers, symbols
            openssl rand -base64 48 | tr -d "=+/" | head -c "$length"
            ;;
        *)
            log_error "Invalid complexity level: $complexity"
            return 1
            ;;
    esac
# Rotate secrets
rotate_secrets() {
    log_info "Starting secret rotation"
    local config_file="$SECURITY_DIR/secrets/secrets-config.json"
    if [[ ! -f "$config_file" ]]; then
        log_error "Secrets configuration not found: $config_file"
        return 1
    fi
    # Read secrets configuration
    local secrets
    secrets=$(jq -r '.secrets | keys[]' "$config_file")
    for secret_name in $secrets; do
        log_info "Rotating secret: $secret_name"
        # Get secret configuration
        local complexity
        complexity=$(jq -r ".secrets.\"$secret_name\".complexity" "$config_file")
        # Generate new password
        local new_password
        new_password=$(generate_password 32 "$complexity")
        # Store new secret
        if [[ "$VAULT_ENABLED" == "true" ]]; then
            store_secret "$secret_name" "$new_password"
        fi
        # Update environment file
        update_env_secret "$secret_name" "$new_password"
        log_success "Secret rotated: $secret_name"
    done
    log_success "Secret rotation completed"
# Update secret in environment file
update_env_secret() {
    local env_file="${3:-$PROJECT_ROOT/.env}"
    # Map secret names to environment variables
    local env_var=""
    case "$secret_name" in
        n8n_basic_auth_password)
            env_var="N8N_BASIC_AUTH_PASSWORD"
        postgres_password)
            env_var="POSTGRES_PASSWORD"
        redis_password)
            env_var="REDIS_PASSWORD"
        n8n_encryption_key)
            env_var="N8N_ENCRYPTION_KEY"
        n8n_jwt_secret)
            env_var="N8N_JWT_SECRET"
            ;;
        *)
            log_warning "Unknown secret name: $secret_name"
            return 1
            ;;
    esac
    if [[ -f "$env_file" ]]; then
        # Update existing variable or add new one
        if grep -q "^$env_var=" "$env_file"; then
            sed -i "s/^$env_var=.*/$env_var=$secret_value/" "$env_file"
        else
            echo "$env_var=$secret_value" >> "$env_file"
        fi
        log_info "Updated $env_var in $env_file"
    else
        log_warning "Environment file not found: $env_file"
    fi
# Backup secrets
backup_secrets() {
    local backup_file="${1:-$SECURITY_DIR/secrets/secrets-backup-$(date +%Y%m%d_%H%M%S).tar.gz}"
    log_info "Creating secrets backup: $backup_file"
    # Create temporary directory for backup
    local temp_dir
    temp_dir=$(mktemp -d)
    local backup_dir="$temp_dir/secrets-backup"
    mkdir -p "$backup_dir"
    # Copy configuration files
    if [[ -f "$SECURITY_DIR/secrets/secrets-config.json" ]]; then
        cp "$SECURITY_DIR/secrets/secrets-config.json" "$backup_dir/"
    fi
    # Export secrets from Vault if enabled
    if [[ "$VAULT_ENABLED" == "true" && -f "$VAULT_TOKEN_FILE" ]]; then
        export_vault_secrets "$backup_dir/vault-secrets.json"
    fi
    # Copy encrypted environment file if it exists
    if [[ -f "$ENCRYPTED_ENV_FILE" ]]; then
        cp "$ENCRYPTED_ENV_FILE" "$backup_dir/"
    fi
    # Create backup archive
    tar -czf "$backup_file" -C "$temp_dir" secrets-backup
    # Clean up temporary directory
    rm -rf "$temp_dir"
    chmod 600 "$backup_file"
    log_success "Secrets backup created: $backup_file"
# Export secrets from Vault
export_vault_secrets() {
    local output_file="$1"
    if [[ ! -f "$VAULT_TOKEN_FILE" ]]; then
        log_error "Vault token file not found"
        return 1
    fi
    local vault_token
    vault_token=$(cat "$VAULT_TOKEN_FILE")
    # List all secrets
    local secrets_list
    secrets_list=$(curl -s -X LIST "$VAULT_URL/v1/$VAULT_SECRETS_PATH/metadata" \
        -H "X-Vault-Token: $vault_token" | jq -r '.data.keys[]' 2>/dev/null || echo "")
    if [[ -z "$secrets_list" ]]; then
        log_warning "No secrets found in Vault"
        echo "{}" > "$output_file"
        return 0
    fi
    # Export each secret
    local exported_secrets="{}"
    for secret_name in $secrets_list; do
        local secret_value
        secret_value=$(retrieve_secret "$secret_name" 2>/dev/null || echo "")
        if [[ -n "$secret_value" ]]; then
            exported_secrets=$(echo "$exported_secrets" | jq --arg name "$secret_name" --arg value "$secret_value" '. + {($name): $value}')
        fi
    done
    echo "$exported_secrets" > "$output_file"
    chmod 600 "$output_file"
    log_info "Vault secrets exported to: $output_file"
# Show secrets status
show_status() {
    log_info "Secrets Management Status"
    echo "=========================="
    # Check encryption key
    if [[ -f "$ENCRYPTION_KEY_FILE" ]]; then
        log_success "Encryption key: Present"
    else
        log_warning "Encryption key: Missing"
    fi
    # Check Vault status
    if [[ "$VAULT_ENABLED" == "true" ]]; then
        if curl -s "$VAULT_URL/v1/sys/health" > /dev/null; then
            log_success "Vault: Accessible"
            
            if [[ -f "$VAULT_TOKEN_FILE" ]]; then
                log_success "Vault token: Present"
            else
                log_warning "Vault token: Missing"
            fi
        else
            log_error "Vault: Not accessible"
        fi
    else
        log_info "Vault: Disabled"
    fi
    # Check encrypted environment file
    if [[ -f "$ENCRYPTED_ENV_FILE" ]]; then
        log_success "Encrypted environment: Present"
    else
        log_warning "Encrypted environment: Missing"
    fi
    # Check secrets configuration
    if [[ -f "$SECURITY_DIR/secrets/secrets-config.json" ]]; then
        log_success "Secrets configuration: Present"
        local secret_count
        secret_count=$(jq -r '.secrets | length' "$SECURITY_DIR/secrets/secrets-config.json")
        log_info "Configured secrets: $secret_count"
    else
        log_warning "Secrets configuration: Missing"
    fi
# Clean up secrets
clean_secrets() {
    local force="${1:-false}"
    if [[ "$force" != "true" ]]; then
        echo -n "This will remove all secrets and configurations. Are you sure? (y/N): "
        read -r confirmation
        if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
            log_info "Operation cancelled"
            return 0
    log_warning "Cleaning up secrets management"
    # Remove secrets directory
    if [[ -d "$SECURITY_DIR/secrets" ]]; then
        rm -rf "$SECURITY_DIR/secrets"
        log_info "Removed secrets directory"
    fi
    # Remove encrypted environment file
    if [[ -f "$ENCRYPTED_ENV_FILE" ]]; then
        rm -f "$ENCRYPTED_ENV_FILE"
        log_info "Removed encrypted environment file"
    fi
    log_success "Secrets cleanup completed"
# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vault-url)
                VAULT_URL="$2"
                shift 2
                ;;
            --vault-token)
                echo "$2" > "$VAULT_TOKEN_FILE"
                chmod 600 "$VAULT_TOKEN_FILE"
                shift 2
                ;;
            --key-file)
                ENCRYPTION_KEY_FILE="$2"
                shift 2
                ;;
            --env-file)
                ENV_FILE="$2"
                shift 2
                ;;
            --secret-name)
                SECRET_NAME="$2"
                shift 2
                ;;
            --secret-value)
                SECRET_VALUE="$2"
                shift 2
                ;;
            --backup-file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}
# Main function
main() {
    local command="${1:-help}"
    shift || true
    # Parse arguments
    parse_arguments "$@"
    # Check dependencies
    check_dependencies
    # Execute command
    case "$command" in
        init)
            init_secrets
        encrypt)
            encrypt_env_file "${ENV_FILE:-$PROJECT_ROOT/.env}"
        decrypt)
            decrypt_env_file "${ENCRYPTED_ENV_FILE}" "${ENV_FILE:-$PROJECT_ROOT/.env.decrypted}"
        store)
            if [[ -z "${SECRET_NAME:-}" || -z "${SECRET_VALUE:-}" ]]; then
                log_error "Secret name and value are required"
                exit 1
            fi
            store_secret "$SECRET_NAME" "$SECRET_VALUE"
            ;;
        retrieve)
            if [[ -z "${SECRET_NAME:-}" ]]; then
                log_error "Secret name is required"
                exit 1
            fi
            retrieve_secret "$SECRET_NAME"
            ;;
        rotate)
            rotate_secrets
            ;;
        backup)
            backup_secrets "${BACKUP_FILE:-}"
            ;;
        restore)
            log_error "Restore functionality not yet implemented"
            exit 1
            ;;
        status)
            show_status
            ;;
        clean)
            clean_secrets "${FORCE:-false}"
            ;;
        help|--help)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
# Run main function with all arguments
main "$@"
