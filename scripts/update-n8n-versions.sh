#!/bin/bash

# N8N Automated Version Update Script
# Updates N8N to latest versions in docker-compose.yml and security.yml

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 N8N Automated Version Updater${NC}"
echo "===================================="

# Function to get latest GitHub release
get_latest_github_version() {
    curl -s "https://api.github.com/repos/n8n-io/n8n/releases/latest" | \
        grep '"tag_name"' | \
        cut -d'"' -f4 | \
        sed 's/n8n@//'
}

# Function to get latest npm package version
get_latest_npm_version() {
    npm view n8n-core@latest version 2>/dev/null || echo "unknown"
}

# Function to check Docker Hub for image existence
check_docker_image_exists() {
    local version=$1
    echo -e "${YELLOW}🔍 Checking if Docker image n8nio/n8n:${version} exists...${NC}"
    if docker manifest inspect "n8nio/n8n:${version}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get current and latest versions
CURRENT_DOCKER=$(grep "image: n8nio/n8n:" docker-compose.yml | sed 's/.*n8nio\/n8n://' | tr -d ' ')
LATEST_GITHUB=$(get_latest_github_version)
LATEST_NPM=$(get_latest_npm_version)

echo "Current Docker version: ${CURRENT_DOCKER}"
echo "Latest GitHub release:  ${LATEST_GITHUB}"
echo "Latest npm package:     ${LATEST_NPM}"
echo ""

# Check if Docker image exists
if ! check_docker_image_exists "${LATEST_GITHUB}"; then
    echo -e "${RED}❌ Docker image n8nio/n8n:${LATEST_GITHUB} not found on Docker Hub${NC}"
    echo -e "${YELLOW}⚠️  Will keep current version ${CURRENT_DOCKER}${NC}"
    exit 1
fi

# Update Docker Compose files
echo -e "${BLUE}📝 Updating Docker Compose files...${NC}"

# Update main docker-compose.yml
sed -i "s/n8nio\/n8n:${CURRENT_DOCKER}/n8nio\/n8n:${LATEST_GITHUB}/" docker-compose.yml
echo -e "${GREEN}✅ Updated docker-compose.yml${NC}"

# Update security workflow
sed -i "s/n8nio\/n8n:${CURRENT_DOCKER}/n8nio\/n8n:${LATEST_GITHUB}/" .github/workflows/security.yml
echo -e "${GREEN}✅ Updated .github/workflows/security.yml${NC}"

# Update npm packages if newer version available
CURRENT_NPM=$(grep '"n8n-core":' nodes/package.json | sed 's/.*"n8n-core": *"[^0-9]*\([0-9.]*\)".*/\1/')

if [[ "${LATEST_NPM}" != "unknown" ]] && [[ "${CURRENT_NPM}" != "${LATEST_NPM}" ]]; then
    echo -e "${BLUE}📦 Updating npm packages...${NC}"
    cd nodes
    
    # Update package.json versions
    sed -i "s/\"n8n-core\": *\"[^\"]*\"/\"n8n-core\": \"^${LATEST_NPM}\"/" package.json
    sed -i "s/\"n8n-workflow\": *\"[^\"]*\"/\"n8n-workflow\": \"^${LATEST_NPM}\"/" package.json
    sed -i "s/\"n8n-workflow\": *\"[^\"]*\"/\"n8n-workflow\": \"^${LATEST_NPM}\"/" package.json
    
    # Install updated packages
    echo -e "${YELLOW}📥 Installing updated packages...${NC}"
    npm install
    
    echo -e "${GREEN}✅ Updated npm packages to ${LATEST_NPM}${NC}"
    cd ..
else
    echo -e "${GREEN}✅ npm packages are already up to date${NC}"
fi

# Run security check on new version
echo -e "${BLUE}🔒 Running security check on updated version...${NC}"
echo "Pulling latest image..."
docker pull "n8nio/n8n:${LATEST_GITHUB}"

# Show what changed
echo ""
echo -e "${GREEN}🎉 Update Summary:${NC}"
echo "=================="
echo "Docker version: ${CURRENT_DOCKER} → ${LATEST_GITHUB}"
if [[ "${LATEST_NPM}" != "unknown" ]]; then
    echo "npm packages:   ${CURRENT_NPM} → ${LATEST_NPM}"
fi
echo ""

# Suggest next steps
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "=============="
echo "1. Test the updated configuration:"
echo "   docker compose up -d"
echo ""
echo "2. Run security scans:"
echo "   make security-scan"
echo ""
echo "3. Commit the changes:"
echo "   git add docker-compose.yml .github/workflows/security.yml nodes/package.json nodes/package-lock.json"
echo "   git commit -m \"chore: update N8N to version ${LATEST_GITHUB}\""
echo ""

echo -e "${GREEN}✅ N8N version update completed successfully!${NC}"
