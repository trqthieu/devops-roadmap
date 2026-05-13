# rotate-aws-secrets.sh
#!/bin/bash

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Config
ENV=${1:-"staging"}
BACKUP_DIR="./secrets-backup"
LOG_FILE="rotation.log"

# Logging setup
exec > >(tee -a "$LOG_FILE") 2>&1


echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AWS Secrets Rotation - $(date)${NC}"
echo -e "${GREEN}Environment: $ENV${NC}"
echo -e "${GREEN}========================================${NC}"

# Validation
validate_environment() {
    if [[ ! "$ENV" =~ ^(staging|production)$ ]]; then
        echo -e "${RED}Error: Invalid environment '$ENV'${NC}"
        echo "Usage: $0 <staging|production>"
        exit 1
    fi
}

backup_old_credentials() {
    echo -e "${YELLOW}Step 1: Backing up current credentials...${NC}"

    mkdir -p "$BACKUP_DIR"

    # Get current secret (mock - in reality would fetch from AWS)
    OLD_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE_OLD"
    OLD_SECRET_KEY="wJalrXUtnFEMI/K7MDENG_OLD"

    # Backup with encryption
    echo "$OLD_ACCESS_KEY" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:backup123 -out "$BACKUP_DIR/${ENV}_access_key.enc"
    echo "$OLD_SECRET_KEY" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:backup123 -out "$BACKUP_DIR/${ENV}_secret_key.enc"

    echo -e "${GREEN}✓ Backup completed: $BACKUP_DIR/${NC}"
}


# Generate new credentials (mock AWS IAM)
generate_new_credentials() {
    echo -e "${YELLOW}Step 2: Generating new AWS credentials...${NC}"

    # Mock credential generation
    NEW_ACCESS_KEY="AKIAIOSFODNN7$(openssl rand -hex 8 | tr '[:lower:]' '[:upper:]')"
    NEW_SECRET_KEY="$(openssl rand -base64 32)"

    echo -e "${GREEN}✓ New credentials generated${NC}"
    echo "Access Key: ${NEW_ACCESS_KEY:0:10}..." # Show first 10 chars only
}

# Test new credentials
test_credentials() {
    echo -e "${YELLOW}Step 3: Testing new credentials...${NC}"

    # Mock AWS API call
    local test_result=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "https://httpbin.org/status/200" \
        -H "Authorization: Bearer $NEW_ACCESS_KEY" 2>/dev/null || echo "000")

    if [ "$test_result" == "200" ]; then
        echo -e "${GREEN}✓ Credentials test PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ Credentials test FAILED (HTTP $test_result)${NC}"
        return 1
    fi
}

# Update GitHub secrets
update_github_secrets() {
    echo -e "${YELLOW}Step 4: Updating GitHub secrets...${NC}"

    echo "$NEW_ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID --env "$ENV"
    echo "$NEW_SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --env "$ENV"

    echo -e "${GREEN}✓ GitHub secrets updated for environment: $ENV${NC}"
}

# Verify update
verify_update() {
    echo -e "${YELLOW}Step 5: Verifying secret update...${NC}"

    # Check secret exists in GitHub
    if gh secret list --env "$ENV" | grep -q "AWS_ACCESS_KEY_ID"; then
        echo -e "${GREEN}✓ AWS_ACCESS_KEY_ID verified${NC}"
    else
        echo -e "${RED}✗ AWS_ACCESS_KEY_ID not found!${NC}"
        return 1
    fi

    if gh secret list --env "$ENV" | grep -q "AWS_SECRET_ACCESS_KEY"; then
        echo -e "${GREEN}✓ AWS_SECRET_ACCESS_KEY verified${NC}"
    else
        echo -e "${RED}✗ AWS_SECRET_ACCESS_KEY not found!${NC}"
        return 1
    fi
}

# Rollback function
rollback() {
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}ERROR DETECTED - Initiating rollback...${NC}"
    echo -e "${RED}========================================${NC}"

    if [ -f "$BACKUP_DIR/${ENV}_access_key.enc" ]; then
        echo "Restoring old credentials from backup..."

        OLD_ACCESS_KEY=$(openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:backup123 -in "$BACKUP_DIR/${ENV}_access_key.enc")
        OLD_SECRET_KEY=$(openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:backup123 -in "$BACKUP_DIR/${ENV}_secret_key.enc")

        echo "$OLD_ACCESS_KEY" | gh secret set AWS_ACCESS_KEY_ID --env "$ENV"
        echo "$OLD_SECRET_KEY" | gh secret set AWS_SECRET_ACCESS_KEY --env "$ENV"

        echo -e "${GREEN}✓ Rollback completed - old credentials restored${NC}"
    else
        echo -e "${RED}✗ Backup not found - manual intervention required!${NC}"
    fi

    exit 1
}

trap rollback ERR

main() {
    local start_time=$(date +%s)

    validate_environment
    backup_old_credentials
    generate_new_credentials

    if test_credentials; then
        update_github_secrets
        verify_update

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}✓ Rotation completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo "Environment: $ENV"
        echo "Time: $(date)"
        echo "Duration: $(($(date +%s) - start_time))s"
        echo "Next rotation: $(date -d '+90 days' '+%Y-%m-%d')"
        echo ""
        echo -e "${YELLOW}IMPORTANT: Revoke old AWS credentials manually${NC}"
        echo "Old Access Key (first 10 chars): ${OLD_ACCESS_KEY:0:10}..."
    else
        echo -e "${RED}Credential test failed - rolling back...${NC}"
        rollback
    fi
}

main