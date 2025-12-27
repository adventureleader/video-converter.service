#!/bin/bash
################################################################################
# Video Converter Service - Uninstall Script
#
# This script completely removes the video-converter service from your system.
# It will:
#   - Stop and disable the systemd service
#   - Remove service files and binaries
#   - Remove configuration and log directories
#   - Remove runtime files and queue directories
#   - Optionally remove the service user account
#
# Usage:
#   sudo ./uninstall_videoconverter.sh
#
# WARNING: This script will permanently delete files. Ensure you have backups
#          of any important data before running.
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Video Converter Service - Uninstall${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status messages
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Confirmation prompt
echo -e "${YELLOW}WARNING: This will permanently remove the video-converter service.${NC}"
echo "This action cannot be undone."
echo ""
read -p "Are you sure you want to continue? (yes/no): " -r
echo ""
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Step 1: Stop the service
print_status "Stopping video-converter service..."
if systemctl is-active --quiet video-converter; then
    systemctl stop video-converter
    print_success "Service stopped"
else
    print_warning "Service is not running"
fi

# Step 2: Disable the service
print_status "Disabling video-converter service..."
if systemctl is-enabled --quiet video-converter 2>/dev/null; then
    systemctl disable video-converter
    print_success "Service disabled"
else
    print_warning "Service is not enabled"
fi

# Step 3: Remove systemd service file
print_status "Removing systemd service file..."
if [ -f /etc/systemd/system/video-converter.service ]; then
    rm -f /etc/systemd/system/video-converter.service
    print_success "Service file removed"
else
    print_warning "Service file not found"
fi

# Step 4: Reload systemd daemon
print_status "Reloading systemd daemon..."
systemctl daemon-reload
print_success "Systemd daemon reloaded"

# Step 5: Remove service binary
print_status "Removing service binary..."
if [ -f /usr/local/bin/videoconverter ]; then
    rm -f /usr/local/bin/videoconverter
    print_success "Binary removed"
else
    print_warning "Binary not found"
fi

# Step 6: Remove configuration files
print_status "Removing configuration files..."
if [ -d /etc/videoconverter ]; then
    rm -rf /etc/videoconverter
    print_success "Configuration directory removed"
else
    print_warning "Configuration directory not found"
fi

# Step 7: Remove log files
print_status "Removing log files..."
if [ -d /var/log/videoconverter ]; then
    rm -rf /var/log/videoconverter
    print_success "Log directory removed"
else
    print_warning "Log directory not found"
fi

# Step 8: Remove runtime files
print_status "Removing runtime files..."
if [ -d /var/run/videoconverter ]; then
    rm -rf /var/run/videoconverter
    print_success "Runtime directory removed"
else
    print_warning "Runtime directory not found"
fi

# Step 9: Remove queue directory
print_status "Removing queue directory..."
if [ -d /var/lib/videoconverter ]; then
    rm -rf /var/lib/videoconverter
    print_success "Queue directory removed"
else
    print_warning "Queue directory not found"
fi

# Step 10: Remove service user (optional)
echo ""
read -p "Remove the 'videoconverter' user account? (yes/no): " -r
echo ""
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_status "Removing service user..."
    if id "videoconverter" &>/dev/null; then
        userdel -r videoconverter 2>/dev/null || true
        print_success "User account removed"
    else
        print_warning "User account not found"
    fi
else
    print_warning "User account not removed"
fi

# Verification
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

print_status "Checking for remaining files..."
remaining_files=$(find / -name "*videoconverter*" 2>/dev/null | wc -l)

if [ "$remaining_files" -eq 0 ]; then
    print_success "No remaining videoconverter files found"
else
    print_warning "Found $remaining_files remaining files:"
    find / -name "*videoconverter*" 2>/dev/null | head -10
fi

# Final status
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "The video-converter service has been successfully removed."
echo ""
echo "Additional cleanup options:"
echo "  - Remove converted files: sudo rm -rf /path/to/converted/videos"
echo "  - Restore original files: sudo cp -r /backup/original/videos /path/to/videos"
echo ""
