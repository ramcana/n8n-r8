#!/bin/bash

# N8N Version Checker Script
# Checks for latest N8N versions and suggests updates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 N8N Version Checker${NC}"
echo "=================================="

# Function to get current version from docker-compose.yml
get_current_docker_version() {
    grep "image: n8nio/n8n:" docker-compose.yml | sed 's/.*n8nio\/n8n://' | tr -d ' '
}

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
    docker manifest inspect "n8nio/n8n:${version}" >/dev/null 2>&1
}

# Get versions
echo -e "${YELLOW}📋 Checking current versions...${NC}"
CURRENT_DOCKER=$(get_current_docker_version)
LATEST_GITHUB=$(get_latest_github_version)
LATEST_NPM=$(get_latest_npm_version)

echo "Current Docker version: ${CURRENT_DOCKER}"
echo "Latest GitHub release:  ${LATEST_GITHUB}"
echo "Latest npm package:     ${LATEST_NPM}"
echo ""

# Check if updates are available
DOCKER_UPDATE_AVAILABLE=false
NPM_UPDATE_AVAILABLE=false

# Compare versions (simple string comparison for now)
if [[ "${CURRENT_DOCKER}" != "${LATEST_GITHUB}" ]]; then
    if check_docker_image_exists "${LATEST_GITHUB}"; then
        DOCKER_UPDATE_AVAILABLE=true
        echo -e "${GREEN}✅ Docker image update available: ${CURRENT_DOCKER} → ${LATEST_GITHUB}${NC}"
    else
        echo -e "${YELLOW}⚠️  GitHub release ${LATEST_GITHUB} not yet available as Docker image${NC}"
    fi
else
    echo -e "${GREEN}✅ Docker image is up to date${NC}"
fi

# Check npm packages
CURRENT_NPM=$(grep '"n8n-core":' nodes/package.json | sed 's/.*"n8n-core": *"[^0-9]*\([0-9.]*\)".*/\1/')
if [[ "${CURRENT_NPM}" != "${LATEST_NPM}" ]] && [[ "${LATEST_NPM}" != "unknown" ]]; then
    NPM_UPDATE_AVAILABLE=true
    echo -e "${GREEN}✅ npm package update available: ${CURRENT_NPM} → ${LATEST_NPM}${NC}"
else
    echo -e "${GREEN}✅ npm packages are up to date${NC}"
fi

echo ""

# Provide update commands if needed
if [[ "${DOCKER_UPDATE_AVAILABLE}" == "true" ]] || [[ "${NPM_UPDATE_AVAILABLE}" == "true" ]]; then
    echo -e "${BLUE}🔧 Update Commands:${NC}"
    echo "==================="
    
    if [[ "${DOCKER_UPDATE_AVAILABLE}" == "true" ]]; then
        echo -e "${YELLOW}Docker Image Update:${NC}"
        echo "sed -i 's/n8nio\/n8n:${CURRENT_DOCKER}/n8nio\/n8n:${LATEST_GITHUB}/' docker-compose.yml"
        echo "sed -i 's/n8nio\/n8n:${CURRENT_DOCKER}/n8nio\/n8n:${LATEST_GITHUB}/' .github/workflows/security.yml"
        echo ""
    fi
    
    if [[ "${NPM_UPDATE_AVAILABLE}" == "true" ]]; then
        echo -e "${YELLOW}npm Package Update:${NC}"
        echo "cd nodes && npm install n8n-core@${LATEST_NPM} n8n-workflow@${LATEST_NPM}"
        echo ""
    fi
    
    echo -e "${BLUE}💡 Automated Update:${NC}"
    echo "Run: ./scripts/update-n8n-versions.sh"
    echo ""
else
    echo -e "${GREEN}🎉 All versions are up to date!${NC}"
fi

# Security reminder
echo -e "${RED}🔒 Security Reminder:${NC}"
echo "After updating, run security scans:"
echo "docker run --rm aquasecurity/trivy:latest image n8nio/n8n:${LATEST_GITHUB}"
echo ""

exit 0
