#!/bin/bash
################################################################################
# Video Converter Installation Script for Ubuntu and Derivatives
#
# This script installs and configures the Video Converter service on Ubuntu
# and Ubuntu-based systems. It handles package installation, user/group creation,
# directory setup, configuration, and systemd service integration.
#
# Usage:
#   sudo ./install_videoconverter.sh [OPTIONS]
#
# Options:
#   --user <name>      System user name (default: videoconverter)
#   --group <group>    System group name (default: videoconverter)
#   --help             Show this help message
#
# Author: Video Converter Team
# Version: 1.0.0
# License: MIT
################################################################################

set -euo pipefail

################################################################################
# CONSTANTS AND CONFIGURATION
################################################################################

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
SERVICE_USER="videoconverter"
SERVICE_GROUP="videoconverter"

# Directory paths
readonly ETC_DIR="/etc/videoconverter"
readonly LOG_DIR="/var/log/videoconverter"
readonly LIB_DIR="/var/lib/videoconverter"
readonly RUN_DIR="/var/run/videoconverter"
readonly BIN_DIR="/usr/local/bin"
readonly SYSTEMD_DIR="/etc/systemd/system"

# File paths
readonly PYTHON_SCRIPT="${SCRIPT_DIR}/videoconverter"
readonly SERVICE_FILE="${SYSTEMD_DIR}/videoconverter.service"
readonly ENV_FILE="${ETC_DIR}/videoconverter.env"
readonly CONFIG_FILE="${ETC_DIR}/config.yml"

# Packages to install
declare -a REQUIRED_PACKAGES=(
    "ffmpeg"
    "python3-venv"
    "python3-pip"
    "python3-watchdog"
    "python3-yaml"
)

# Optional GPU driver packages
declare -a GPU_PACKAGES=(
    "nvidia-driver-open"
    "mesa-va-drivers"
    "intel-media-va-driver-non-free"
)

# Progress indicators
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly ARROW="→"

################################################################################
# HELPER FUNCTIONS - LOGGING AND OUTPUT
################################################################################

# Print colored output
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        success)
            echo -e "\033[32m${CHECK_MARK}\033[0m $message"
            ;;
        error)
            echo -e "\033[31m${CROSS_MARK}\033[0m $message" >&2
            ;;
        info)
            echo -e "\033[34m${ARROW}\033[0m $message"
            ;;
        warning)
            echo -e "\033[33m⚠\033[0m $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Log message with timestamp
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        INFO)
            print_status "info" "[$timestamp] $message"
            ;;
        SUCCESS)
            print_status "success" "[$timestamp] $message"
            ;;
        ERROR)
            print_status "error" "[$timestamp] $message"
            ;;
        WARNING)
            print_status "warning" "[$timestamp] $message"
            ;;
    esac
}

# Print section header
print_section() {
    local title="$1"
    echo ""
    echo "================================================================================"
    echo "  $title"
    echo "================================================================================"
}

# Print help message
show_help() {
    cat << EOF
Video Converter Installation Script v${SCRIPT_VERSION}

Usage: sudo ./install_videoconverter.sh [OPTIONS]

Options:
    --user <name>      System user name (default: videoconverter)
    --group <group>    System group name (default: videoconverter)
    --help             Show this help message

Examples:
    sudo ./install_videoconverter.sh
    sudo ./install_videoconverter.sh --user vcuser --group vcgroup
    sudo ./install_videoconverter.sh --help

EOF
}

################################################################################
# HELPER FUNCTIONS - VALIDATION AND CHECKS
################################################################################

# Check if running as root
check_root() {
    if [[ $(id -u) -ne 0 ]]; then
        log_message "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
    log_message "SUCCESS" "Running as root"
}

# Check if Ubuntu or Ubuntu derivative
check_ubuntu_version() {
    if [[ ! -f /etc/os-release ]]; then
        log_message "WARNING" "Cannot determine OS version"
        return 0
    fi
    
    source /etc/os-release
    
    # Check if it's Ubuntu or an Ubuntu derivative
    if [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
        log_message "SUCCESS" "Ubuntu/Ubuntu derivative detected: $PRETTY_NAME"
    else
        log_message "WARNING" "This script is designed for Ubuntu and derivatives (detected: $PRETTY_NAME)"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if user exists
user_exists() {
    getent passwd "$1" >/dev/null 2>&1
}

# Check if group exists
group_exists() {
    getent group "$1" >/dev/null 2>&1
}

# Check if package is installed
package_installed() {
    dpkg -l | grep -q "^ii  $1"
}

################################################################################
# PHASE 1: PACKAGE INSTALLATION
################################################################################

install_packages() {
    print_section "Phase 1: Installing Required Packages"
    
    log_message "INFO" "Updating package lists..."
    if apt-get update >/dev/null 2>&1; then
        log_message "SUCCESS" "Package lists updated"
    else
        log_message "ERROR" "Failed to update package lists"
        return 1
    fi
    
    # Install required packages
    log_message "INFO" "Installing required packages..."
    local failed_packages=()
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        if package_installed "$package"; then
            log_message "SUCCESS" "Package already installed: $package"
        else
            log_message "INFO" "Installing: $package"
            if apt-get install -y "$package" >/dev/null 2>&1; then
                log_message "SUCCESS" "Installed: $package"
            else
                log_message "ERROR" "Failed to install: $package"
                failed_packages+=("$package")
            fi
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        log_message "ERROR" "Failed to install packages: ${failed_packages[*]}"
        return 1
    fi
    
    # Attempt to install GPU drivers (non-critical)
    log_message "INFO" "Attempting to install GPU drivers (optional)..."
    for package in "${GPU_PACKAGES[@]}"; do
        if package_installed "$package"; then
            log_message "SUCCESS" "GPU driver already installed: $package"
        else
            log_message "INFO" "Attempting to install: $package"
            if apt-get install -y "$package" >/dev/null 2>&1; then
                log_message "SUCCESS" "Installed GPU driver: $package"
            else
                log_message "WARNING" "GPU driver not available: $package (this is optional)"
            fi
        fi
    done
    
    log_message "SUCCESS" "Package installation phase completed"
}

################################################################################
# PHASE 2: USER AND GROUP CREATION
################################################################################

create_user_and_group() {
    print_section "Phase 2: Creating User and Group"
    
    # Create group if it doesn't exist
    if group_exists "$SERVICE_GROUP"; then
        log_message "SUCCESS" "Group already exists: $SERVICE_GROUP"
    else
        log_message "INFO" "Creating system group: $SERVICE_GROUP"
        if groupadd --system "$SERVICE_GROUP" 2>/dev/null; then
            log_message "SUCCESS" "Group created: $SERVICE_GROUP"
        else
            log_message "ERROR" "Failed to create group: $SERVICE_GROUP"
            return 1
        fi
    fi
    
    # Create user if it doesn't exist
    if user_exists "$SERVICE_USER"; then
        log_message "SUCCESS" "User already exists: $SERVICE_USER"
    else
        log_message "INFO" "Creating system user: $SERVICE_USER"
        if useradd \
            --system \
            --group "$SERVICE_GROUP" \
            --home-dir "$LIB_DIR" \
            --shell /usr/sbin/nologin \
            --comment "Video Converter Service" \
            "$SERVICE_USER" 2>/dev/null; then
            log_message "SUCCESS" "User created: $SERVICE_USER"
        else
            log_message "ERROR" "Failed to create user: $SERVICE_USER"
            return 1
        fi
    fi
    
    # Verify user and group
    if user_exists "$SERVICE_USER" && group_exists "$SERVICE_GROUP"; then
        log_message "SUCCESS" "User and group verification successful"
    else
        log_message "ERROR" "User or group verification failed"
        return 1
    fi
}

################################################################################
# PHASE 3: DIRECTORY STRUCTURE SETUP
################################################################################

setup_directories() {
    print_section "Phase 3: Setting Up Directory Structure"
    
    local dirs=(
        "$ETC_DIR:755"
        "$LOG_DIR:750"
        "$LIB_DIR:750"
        "$RUN_DIR:750"
    )
    
    for dir_spec in "${dirs[@]}"; do
        local dir="${dir_spec%:*}"
        local perms="${dir_spec#*:}"
        
        if [[ -d "$dir" ]]; then
            log_message "SUCCESS" "Directory already exists: $dir"
        else
            log_message "INFO" "Creating directory: $dir"
            if mkdir -p "$dir"; then
                log_message "SUCCESS" "Directory created: $dir"
            else
                log_message "ERROR" "Failed to create directory: $dir"
                return 1
            fi
        fi
        
        # Set permissions
        log_message "INFO" "Setting permissions $perms on: $dir"
        if chmod "$perms" "$dir"; then
            log_message "SUCCESS" "Permissions set: $dir ($perms)"
        else
            log_message "ERROR" "Failed to set permissions on: $dir"
            return 1
        fi
        
        # Set ownership
        log_message "INFO" "Setting ownership $SERVICE_USER:$SERVICE_GROUP on: $dir"
        if chown "$SERVICE_USER:$SERVICE_GROUP" "$dir"; then
            log_message "SUCCESS" "Ownership set: $dir ($SERVICE_USER:$SERVICE_GROUP)"
        else
            log_message "ERROR" "Failed to set ownership on: $dir"
            return 1
        fi
    done
    
    log_message "SUCCESS" "Directory setup phase completed"
}

################################################################################
# PHASE 4: CONFIGURATION FILE HANDLING
################################################################################

setup_config_file() {
    print_section "Phase 4: Setting Up Configuration File"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        log_message "SUCCESS" "Configuration file already exists: $CONFIG_FILE"
        log_message "INFO" "Preserving existing configuration"
    else
        log_message "INFO" "Creating sample configuration file: $CONFIG_FILE"
        
        # Create sample config.yml
        cat > "$CONFIG_FILE" << 'YAML_EOF'
# Video Converter Service Configuration
# Ubuntu 24.04 - Production Deployment

service:
  # Logging level: DEBUG, INFO, WARNING, ERROR, CRITICAL
  log_level: INFO
  
  # Maximum concurrent conversion workers
  max_workers: 2
  
  # Conversion timeout in seconds (1 hour default)
  conversion_timeout: 3600

directories:
  # Directories to monitor for video files
  watch_paths:
    - /home/videos/incoming
    - /mnt/media/uploads
  
  # File patterns to match (supports wildcards)
  file_patterns:
    - "*.mkv"
    - "*.mp4"
    - "*.avi"
  
  # Recursive directory monitoring
  recursive: true
  
  # Output directory for converted files (relative or absolute)
  output_dir: ../converted

logging:
  # Log directory path
  log_dir: /var/log/videoconverter
  
  # Log rotation size in bytes (10MB default)
  rotation_size: 10485760
  
  # Log retention in days
  retention_days: 14

file_handling:
  # Delete original files after successful conversion
  delete_original: true
  
  # Preserve file permissions
  preserve_permissions: true

error_handling:
  # Maximum retry attempts for failed conversions
  max_retries: 3
  
  # Delay between retries in seconds
  retry_delay: 60

advanced:
  # Lockfile path for process synchronization
  lockfile: /var/run/videoconverter/videoconverter.lock
  
  # File stability check interval (seconds)
  stability_check_interval: 2
  
  # File stability check duration (seconds)
  stability_check_duration: 5
YAML_EOF
        
        if [[ -f "$CONFIG_FILE" ]]; then
            log_message "SUCCESS" "Configuration file created: $CONFIG_FILE"
        else
            log_message "ERROR" "Failed to create configuration file"
            return 1
        fi
    fi
    
    # Set permissions (readable by all, writable by root)
    if chmod 644 "$CONFIG_FILE"; then
        log_message "SUCCESS" "Configuration file permissions set: 644"
    else
        log_message "ERROR" "Failed to set configuration file permissions"
        return 1
    fi
    
    log_message "SUCCESS" "Configuration file setup phase completed"
}

################################################################################
# PHASE 5: ENVIRONMENT FILE CREATION
################################################################################

setup_environment_file() {
    print_section "Phase 5: Creating Environment File"
    
    log_message "INFO" "Creating environment file: $ENV_FILE"
    
    cat > "$ENV_FILE" << EOF
# Video Converter Service Environment Variables
# Sourced by systemd service

# Configuration file path
CONFIG_PATH=$CONFIG_FILE

# Log directory path
LOG_PATH=$LOG_DIR

# Lockfile path
LOCK_PATH=$RUN_DIR/videoconverter.lock
EOF
    
    if [[ -f "$ENV_FILE" ]]; then
        log_message "SUCCESS" "Environment file created: $ENV_FILE"
    else
        log_message "ERROR" "Failed to create environment file"
        return 1
    fi
    
    # Set permissions (readable by all, writable by root)
    if chmod 644 "$ENV_FILE"; then
        log_message "SUCCESS" "Environment file permissions set: 644"
    else
        log_message "ERROR" "Failed to set environment file permissions"
        return 1
    fi
    
    log_message "SUCCESS" "Environment file setup phase completed"
}

################################################################################
# PHASE 6: PYTHON SCRIPT INSTALLATION
################################################################################

install_python_script() {
    print_section "Phase 6: Installing Python Script"
    
    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        log_message "ERROR" "Python script not found: $PYTHON_SCRIPT"
        return 1
    fi
    
    log_message "INFO" "Copying Python script to: $BIN_DIR/videoconverter"
    
    if cp "$PYTHON_SCRIPT" "$BIN_DIR/videoconverter"; then
        log_message "SUCCESS" "Python script copied"
    else
        log_message "ERROR" "Failed to copy Python script"
        return 1
    fi
    
    # Set executable permissions
    if chmod 755 "$BIN_DIR/videoconverter"; then
        log_message "SUCCESS" "Python script permissions set: 755"
    else
        log_message "ERROR" "Failed to set Python script permissions"
        return 1
    fi
    
    # Verify shebang
    local shebang=$(head -n 1 "$BIN_DIR/videoconverter")
    if [[ "$shebang" == "#!/usr/bin/env python3"* ]]; then
        log_message "SUCCESS" "Python script shebang verified: $shebang"
    else
        log_message "WARNING" "Unexpected shebang: $shebang"
    fi
    
    log_message "SUCCESS" "Python script installation phase completed"
}

################################################################################
# PHASE 7: SYSTEMD SERVICE INSTALLATION
################################################################################

install_systemd_service() {
    print_section "Phase 7: Installing Systemd Service"
    
    log_message "INFO" "Generating systemd service file: $SERVICE_FILE"
    
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Video Converter Service - GPU-accelerated video conversion
Documentation=https://github.com/videoconverter/videoconverter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
EnvironmentFile=$ENV_FILE
ExecStart=$BIN_DIR/videoconverter
Restart=on-failure
RestartSec=5s

# Restart with exponential backoff
# First restart: 5s, second: 10s, third: 30s, fourth+: 60s
RestartForceExitStatus=1 6
RestartForceExitStatusRestartSec=5s 10s 30s 60s

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=videoconverter

# Security hardening
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$LOG_DIR $RUN_DIR $LIB_DIR

[Install]
WantedBy=multi-user.target
EOF
    
    if [[ -f "$SERVICE_FILE" ]]; then
        log_message "SUCCESS" "Systemd service file created: $SERVICE_FILE"
    else
        log_message "ERROR" "Failed to create systemd service file"
        return 1
    fi
    
    # Set permissions
    if chmod 644 "$SERVICE_FILE"; then
        log_message "SUCCESS" "Service file permissions set: 644"
    else
        log_message "ERROR" "Failed to set service file permissions"
        return 1
    fi
    
    log_message "SUCCESS" "Systemd service installation phase completed"
}

################################################################################
# PHASE 8: SYSTEMD INTEGRATION
################################################################################

integrate_systemd() {
    print_section "Phase 8: Integrating with Systemd"
    
    log_message "INFO" "Reloading systemd daemon..."
    if systemctl daemon-reload; then
        log_message "SUCCESS" "Systemd daemon reloaded"
    else
        log_message "ERROR" "Failed to reload systemd daemon"
        return 1
    fi
    
    log_message "INFO" "Enabling videoconverter service..."
    if systemctl enable videoconverter >/dev/null 2>&1; then
        log_message "SUCCESS" "Service enabled for auto-start"
    else
        log_message "ERROR" "Failed to enable service"
        return 1
    fi
    
    log_message "INFO" "Starting videoconverter service..."
    if systemctl start videoconverter; then
        log_message "SUCCESS" "Service started"
    else
        log_message "ERROR" "Failed to start service"
        return 1
    fi
    
    # Verify service is running
    sleep 2
    if systemctl is-active --quiet videoconverter; then
        log_message "SUCCESS" "Service is running"
    else
        log_message "ERROR" "Service is not running"
        log_message "INFO" "Checking service status..."
        systemctl status videoconverter || true
        return 1
    fi
    
    log_message "SUCCESS" "Systemd integration phase completed"
}

################################################################################
# PHASE 9: POST-INSTALLATION VERIFICATION AND SUMMARY
################################################################################

post_installation_summary() {
    print_section "Installation Summary"
    
    echo ""
    echo "Installation completed successfully!"
    echo ""
    echo "Service Information:"
    echo "  User:              $SERVICE_USER"
    echo "  Group:             $SERVICE_GROUP"
    echo "  Config File:       $CONFIG_FILE"
    echo "  Log Directory:     $LOG_DIR"
    echo "  Library Directory: $LIB_DIR"
    echo "  Runtime Directory: $RUN_DIR"
    echo "  Service File:      $SERVICE_FILE"
    echo ""
    echo "Next Steps:"
    echo "  1. Edit configuration file:"
    echo "     sudo nano $CONFIG_FILE"
    echo ""
    echo "  2. Update watch paths and output directory as needed"
    echo ""
    echo "  3. Check service status:"
    echo "     sudo systemctl status videoconverter"
    echo ""
    echo "  4. View service logs:"
    echo "     sudo journalctl -u videoconverter -f"
    echo ""
    echo "  5. View application logs:"
    echo "     ls -la $LOG_DIR"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check service status: systemctl status videoconverter"
    echo "  • View recent logs: journalctl -u videoconverter -n 50"
    echo "  • Restart service: systemctl restart videoconverter"
    echo "  • Stop service: systemctl stop videoconverter"
    echo "  • Uninstall: systemctl stop videoconverter && systemctl disable videoconverter"
    echo ""
}

################################################################################
# MAIN INSTALLATION FLOW
################################################################################

main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)
                SERVICE_USER="$2"
                shift 2
                ;;
            --group)
                SERVICE_GROUP="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_message "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Print header
    echo ""
    echo "================================================================================"
    echo "  Video Converter Installation Script v${SCRIPT_VERSION}"
    echo "  Ubuntu and Derivatives Deployment"
    echo "================================================================================"
    echo ""
    
    # Pre-installation checks
    print_section "Pre-Installation Checks"
    check_root
    check_ubuntu_version
    
    # Execute installation phases
    install_packages || exit 1
    create_user_and_group || exit 1
    setup_directories || exit 1
    setup_config_file || exit 1
    setup_environment_file || exit 1
    install_python_script || exit 1
    install_systemd_service || exit 1
    integrate_systemd || exit 1
    
    # Post-installation summary
    post_installation_summary
    
    log_message "SUCCESS" "Installation completed successfully"
    exit 0
}

# Run main function
main "$@"
