# Ubuntu 24.04 Video Converter - Architecture Design Document

## Executive Summary

This document outlines the complete architecture for a production-grade, turn-key video converter solution for Ubuntu 24.04. The system provides automatic GPU detection with intelligent fallback, real-time directory monitoring, and robust error handling with structured logging.

---

## 1. System Overview

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SYSTEMD SERVICE                          │
│              (videoconverter.service)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│  Python Runtime  │    │  Configuration   │
│  (converter.py)  │◄───┤  (/etc/video     │
│                  │    │   converter/)    │
└────────┬─────────┘    └──────────────────┘
         │
    ┌────┴────────────────────────────┐
    │                                 │
    ▼                                 ▼
┌──────────────────┐    ┌──────────────────┐
│  GPU Detection   │    │  Watchdog        │
│  Module          │    │  Monitor         │
└────────┬─────────┘    └────────┬─────────┘
         │                       │
    ┌────┴───────────────────────┴────┐
    │                                 │
    ▼                                 ▼
┌──────────────────┐    ┌──────────────────┐
│  FFmpeg          │    │  File System     │
│  Subprocess      │    │  Events          │
└────────┬─────────┘    └──────────────────┘
         │
    ┌────┴────────────────────────────┐
    │                                 │
    ▼                                 ▼
┌──────────────────┐    ┌──────────────────┐
│  Logging System  │    │  State Management│
│  (Structured)    │    │  (Lockfile)      │
└──────────────────┘    └──────────────────┘
```

### 1.2 Component Responsibilities

| Component | Responsibility |
|-----------|-----------------|
| **Systemd Service** | Process lifecycle, restart policies, resource limits |
| **Python Runtime** | Core conversion logic, GPU detection, file monitoring |
| **Configuration Manager** | YAML parsing, validation, runtime updates |
| **GPU Detection** | Hardware capability detection, encoder selection |
| **Watchdog Monitor** | Real-time directory monitoring, event handling |
| **FFmpeg Wrapper** | Subprocess management, stream handling, error capture |
| **Logging System** | Structured logging, rotation, retention policies |
| **State Manager** | Lockfile handling, process synchronization |

---

## 2. Python Runtime Architecture

### 2.1 Module Structure

```
converter/
├── __init__.py
├── main.py                 # Entry point, service loop
├── config.py              # Configuration parsing & validation
├── gpu_detector.py        # GPU detection & encoder selection
├── file_monitor.py        # Watchdog-based directory monitoring
├── ffmpeg_handler.py      # FFmpeg subprocess management
├── logger.py              # Structured logging setup
├── state_manager.py       # Lockfile & process state
└── exceptions.py          # Custom exception hierarchy
```

### 2.2 GPU Detection Flow

```
GPU Detection Sequence:
┌─────────────────────────────────────────────────────────────┐
│ 1. Check NVIDIA GPU Availability                            │
│    └─ Execute: nvidia-smi --query-gpu=name --format=csv    │
│    └─ If success: Use hevc_nvenc                           │
└─────────────────────────────────────────────────────────────┘
                          │
                    ┌─────┴─────┐
                    │ (Failed)  │
                    ▼           │
┌─────────────────────────────────────────────────────────────┐
│ 2. Check AMD VA-API Support                                 │
│    └─ Execute: vainfo 2>/dev/null | grep -i hevc           │
│    └─ If success: Use hevc_vaapi                           │
└─────────────────────────────────────────────────────────────┘
                          │
                    ┌─────┴─────┐
                    │ (Failed)  │
                    ▼           │
┌─────────────────────────────────────────────────────────────┐
│ 3. Check Intel QSV Support                                  │
│    └─ Execute: ffmpeg -codecs 2>/dev/null | grep hevc_qsv  │
│    └─ If success: Use hevc_qsv                             │
└─────────────────────────────────────────────────────────────┘
                          │
                    ┌─────┴─────┐
                    │ (Failed)  │
                    ▼           │
┌─────────────────────────────────────────────────────────────┐
│ 4. Fallback to CPU Encoding                                 │
│    └─ Use libx265 (software encoder)                        │
│    └─ Log warning about performance impact                  │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 GPU Detector Class Design

```python
class GPUDetector:
    """
    Detects available GPU hardware and selects optimal encoder.
    
    Attributes:
        detected_gpu (str): Type of GPU detected (nvidia, amd, intel, none)
        encoder (str): Selected FFmpeg encoder
        capabilities (dict): GPU capabilities and limits
    
    Methods:
        detect() -> str: Runs detection sequence, returns encoder name
        _check_nvidia() -> bool: NVIDIA GPU detection
        _check_amd_vaapi() -> bool: AMD VA-API detection
        _check_intel_qsv() -> bool: Intel QSV detection
        get_encoder_params() -> dict: Returns encoder-specific FFmpeg args
    """
```

### 2.4 Watchdog Event Handler

```python
class VideoFileEventHandler(FileSystemEventHandler):
    """
    Handles file system events from watchdog.
    
    Methods:
        on_created(event): Triggered when .mkv file appears
        on_modified(event): Ignored (file stability check)
        on_deleted(event): Cleanup if conversion in progress
        _is_stable(filepath) -> bool: Waits for file write completion
        _queue_conversion(filepath): Adds file to conversion queue
    
    Stability Check Logic:
        - Monitor file size changes over 2-second interval
        - Only process when file size stabilizes
        - Prevents partial file processing
    """
```

### 2.5 FFmpeg Handler Architecture

```python
class FFmpegHandler:
    """
    Manages FFmpeg subprocess execution and monitoring.
    
    Methods:
        convert(input_path, output_path, encoder) -> bool
        _build_command(input_path, output_path, encoder) -> list
        _execute_subprocess(cmd) -> Tuple[bool, str]
        _parse_progress(stderr_line) -> dict
        _handle_error(returncode, stderr) -> Exception
    
    Error Handling:
        - Capture stderr for detailed error messages
        - Distinguish between recoverable and fatal errors
        - Log full FFmpeg output for debugging
        - Implement timeout mechanism (configurable)
    
    Progress Tracking:
        - Parse FFmpeg progress output
        - Log conversion milestones
        - Enable future progress reporting
    """
```

### 2.6 Main Service Loop

```python
def main():
    """
    Main service loop with graceful shutdown.
    
    Sequence:
    1. Load configuration from /etc/videoconverter/config.yml
    2. Initialize logging system
    3. Acquire lockfile (exit if already running)
    4. Detect GPU and select encoder
    5. Initialize watchdog observer
    6. Start monitoring configured directories
    7. Process conversion queue
    8. Handle signals (SIGTERM, SIGINT)
    9. Cleanup and exit
    """
```

---

## 3. Bash Installation Script Architecture

### 3.1 Installation Flow

```
Installation Sequence:
┌─────────────────────────────────────────────────────────────┐
│ 1. Prerequisite Checks                                      │
│    ├─ Verify running as root                               │
│    ├─ Check Ubuntu 24.04 version                           │
│    └─ Verify internet connectivity                         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. System Package Installation                              │
│    ├─ Update package manager (apt update)                  │
│    ├─ Install Python 3.12 runtime                          │
│    ├─ Install FFmpeg with codec support                    │
│    ├─ Install watchdog library                             │
│    ├─ Install GPU driver packages (optional)               │
│    └─ Install system utilities (curl, jq, etc.)            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. User & Group Creation                                    │
│    ├─ Create 'videoconverter' system user                  │
│    ├─ Create 'videoconverter' system group                 │
│    ├─ Set home directory to /var/lib/videoconverter        │
│    └─ Restrict shell access (nologin)                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Directory Structure Setup                                │
│    ├─ /etc/videoconverter/          (config)              │
│    ├─ /var/lib/videoconverter/      (state, lockfile)     │
│    ├─ /var/log/videoconverter/      (logs)                │
│    ├─ /opt/videoconverter/          (application code)    │
│    └─ Set appropriate permissions                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Application Deployment                                   │
│    ├─ Copy Python scripts to /opt/videoconverter/          │
│    ├─ Create default config.yml                            │
│    ├─ Set file ownership (videoconverter:videoconverter)   │
│    └─ Set executable permissions                           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Systemd Service Installation                             │
│    ├─ Generate videoconverter.service file                 │
│    ├─ Copy to /etc/systemd/system/                         │
│    ├─ Run systemctl daemon-reload                          │
│    ├─ Enable service (systemctl enable)                    │
│    └─ Start service (systemctl start)                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Verification & Reporting                                 │
│    ├─ Verify service is running                            │
│    ├─ Check GPU detection                                  │
│    ├─ Display installation summary                         │
│    └─ Provide troubleshooting guidance                     │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Package Dependency Resolution

```bash
# Core Dependencies
CORE_PACKAGES=(
    "python3.12"
    "python3.12-venv"
    "python3-pip"
    "ffmpeg"
)

# GPU-Specific Packages (Conditional)
NVIDIA_PACKAGES=(
    "nvidia-driver-XXX"
    "nvidia-utils"
)

AMD_PACKAGES=(
    "libva-dev"
    "libva-glx2"
    "vainfo"
)

INTEL_PACKAGES=(
    "intel-media-driver"
    "libmfx1"
)

# System Utilities
UTILITY_PACKAGES=(
    "curl"
    "jq"
    "systemd"
)
```

### 3.3 Installation Script Structure

```bash
#!/bin/bash
# install.sh - Turn-key installation script

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/videoconverter-install.log"
CONFIG_DIR="/etc/videoconverter"
APP_DIR="/opt/videoconverter"
STATE_DIR="/var/lib/videoconverter"
LOG_DIR="/var/log/videoconverter"
SERVICE_USER="videoconverter"
SERVICE_GROUP="videoconverter"

# Functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
error() { echo "[ERROR] $*" >&2; exit 1; }
check_root() { [[ $EUID -eq 0 ]] || error "Must run as root"; }
check_ubuntu_24() { grep -q "24.04" /etc/os-release || error "Requires Ubuntu 24.04"; }

# Main installation sequence
main() {
    log "Starting videoconverter installation..."
    check_root
    check_ubuntu_24
    install_packages
    create_user_group
    setup_directories
    deploy_application
    install_systemd_service
    verify_installation
    log "Installation complete!"
}

main "$@"
```

---

## 4. Systemd Service Design

### 4.1 Service Configuration Strategy

```ini
[Unit]
Description=Video Converter Service
Documentation=man:videoconverter(1)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/etc/videoconverter/config.yml

[Service]
Type=simple
User=videoconverter
Group=videoconverter
WorkingDirectory=/var/lib/videoconverter

# Process Management
ExecStart=/usr/bin/python3.12 /opt/videoconverter/main.py
Restart=on-failure
RestartSec=10
StartLimitInterval=300
StartLimitBurst=5

# Resource Limits
CPUQuota=80%
MemoryLimit=2G
TasksMax=256

# Security Hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/videoconverter /var/log/videoconverter /media

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=videoconverter

[Install]
WantedBy=multi-user.target
```

### 4.2 Service Dependencies

```
videoconverter.service
├─ Requires: network-online.target (soft dependency)
├─ After: network-online.target
├─ Conflicts: None
└─ Ordering: Starts after multi-user.target
```

### 4.3 Restart Policies

| Scenario | Behavior | Rationale |
|----------|----------|-----------|
| Normal exit (code 0) | No restart | Service completed successfully |
| Abnormal exit | Restart after 10s | Transient error recovery |
| Repeated failures (5 in 5min) | Stop, manual intervention | Prevent restart loops |
| Configuration error | No restart | Admin must fix config |

### 4.4 Resource Limits Rationale

```
CPUQuota=80%
  └─ Prevents system starvation during encoding
  └─ Allows other services to maintain responsiveness

MemoryLimit=2G
  └─ Prevents OOM killer from terminating service
  └─ Configurable based on system resources
  └─ FFmpeg + Python overhead typically < 500MB

TasksMax=256
  └─ Prevents fork bombs
  └─ Sufficient for FFmpeg subprocess + threads
```

---

## 5. Configuration File Structure

### 5.1 YAML Configuration Schema

```yaml
# /etc/videoconverter/config.yml

# Service Configuration
service:
  # Enable/disable the service
  enabled: true
  
  # Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
  log_level: INFO
  
  # Maximum concurrent conversions
  max_workers: 2
  
  # Conversion timeout in seconds (0 = no timeout)
  conversion_timeout: 3600

# Directory Monitoring
directories:
  # List of directories to monitor
  watch_paths:
    - /media/videos/incoming
    - /home/user/Videos/convert
  
  # File patterns to process (glob)
  file_patterns:
    - "*.mkv"
  
  # Output directory (relative to input or absolute)
  output_dir: "../converted"
  
  # Recursive monitoring
  recursive: true

# GPU Configuration
gpu:
  # Force specific encoder (nvidia, amd, intel, cpu)
  # Leave empty for auto-detection
  force_encoder: ""
  
  # GPU device index (for multi-GPU systems)
  device_id: 0
  
  # Enable GPU acceleration
  enabled: true

# FFmpeg Conversion Parameters
conversion:
  # Video codec (hevc_nvenc, hevc_vaapi, hevc_qsv, libx265)
  video_codec: "auto"
  
  # Video bitrate (e.g., "8M", "10M", or "auto" for CRF)
  video_bitrate: "auto"
  
  # CRF quality (0-51, lower = better, only for libx265)
  crf: 28
  
  # Audio codec (aac, libopus, libmp3lame)
  audio_codec: "aac"
  
  # Audio bitrate (e.g., "128k", "192k")
  audio_bitrate: "128k"
  
  # Container format (mkv, mp4)
  output_format: "mkv"
  
  # Additional FFmpeg arguments
  extra_args: []

# File Handling
file_handling:
  # Delete original after successful conversion
  delete_original: true
  
  # Backup original before conversion
  backup_original: false
  
  # Backup directory (if backup_original: true)
  backup_dir: "/var/backups/videoconverter"
  
  # File permissions for output (octal)
  output_permissions: "0644"
  
  # Preserve original file timestamps
  preserve_timestamps: true

# Logging Configuration
logging:
  # Log directory
  log_dir: "/var/log/videoconverter"
  
  # Log file name pattern
  log_file: "converter.log"
  
  # Log level
  level: "INFO"
  
  # Maximum log file size (bytes)
  max_size: 10485760  # 10MB
  
  # Number of backup logs to retain
  backup_count: 14
  
  # Log format (json or text)
  format: "json"
  
  # Include timestamps in logs
  include_timestamp: true

# Error Handling
error_handling:
  # Retry failed conversions
  retry_failed: true
  
  # Number of retry attempts
  max_retries: 3
  
  # Delay between retries (seconds)
  retry_delay: 60
  
  # Email notifications on error (optional)
  notify_email: ""
  
  # Webhook URL for notifications (optional)
  webhook_url: ""

# Advanced Options
advanced:
  # Enable debug mode
  debug: false
  
  # Lockfile location
  lockfile: "/var/lib/videoconverter/converter.lock"
  
  # State database location
  state_db: "/var/lib/videoconverter/state.db"
  
  # Temporary directory for processing
  temp_dir: "/tmp/videoconverter"
  
  # Enable performance profiling
  profile: false
```

### 5.2 Configuration Validation

```python
class ConfigValidator:
    """
    Validates configuration against schema.
    
    Methods:
        validate(config_dict) -> bool
        _validate_directories() -> bool
        _validate_gpu_settings() -> bool
        _validate_conversion_params() -> bool
        _validate_logging() -> bool
        get_errors() -> List[str]
    
    Validation Rules:
        - All required fields present
        - Directory paths exist and are readable
        - Numeric values within acceptable ranges
        - Enum values match allowed options
        - File permissions are valid octal
    """
```

---

## 6. Logging and Error Handling Architecture

### 6.1 Structured Logging Design

```python
class StructuredLogger:
    """
    Provides structured JSON logging with rotation.
    
    Log Levels:
        DEBUG: Detailed diagnostic information
        INFO: General informational messages
        WARNING: Warning messages for recoverable issues
        ERROR: Error messages for failures
        CRITICAL: Critical failures requiring immediate attention
    
    Log Fields (JSON):
        timestamp: ISO 8601 UTC timestamp
        level: Log level
        component: Source component (gpu_detector, ffmpeg_handler, etc.)
        message: Human-readable message
        context: Additional contextual data
        error: Error details (if applicable)
        duration: Operation duration (if applicable)
    """
```

### 6.2 Log Rotation Strategy

```
Log Rotation Configuration:
├─ Max file size: 10MB
├─ Retention period: 14 days
├─ Backup count: 14 files
├─ Rotation trigger: Size-based (daily check)
└─ Compression: gzip (optional)

Example Log Structure:
/var/log/videoconverter/
├─ converter.log              (current)
├─ converter.log.1            (yesterday)
├─ converter.log.2            (2 days ago)
├─ converter.log.3.gz         (3+ days ago, compressed)
└─ converter.log.14.gz        (14 days ago, oldest)
```

### 6.3 Error Handling Strategy

```
Error Classification:
┌─────────────────────────────────────────────────────────────┐
│ FATAL ERRORS (Service stops)                                │
│ ├─ Configuration file missing/invalid                       │
│ ├─ Cannot acquire lockfile (another instance running)       │
│ ├─ Cannot create required directories                       │
│ └─ FFmpeg not installed or broken                           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ RECOVERABLE ERRORS (Retry logic)                            │
│ ├─ File read/write errors (temporary)                       │
│ ├─ FFmpeg conversion failure (retry up to 3x)               │
│ ├─ Watchdog event processing error                          │
│ └─ Temporary GPU unavailability                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ WARNINGS (Logged, service continues)                        │
│ ├─ GPU not available, using CPU fallback                    │
│ ├─ File deletion failed (but conversion succeeded)          │
│ ├─ Configuration reload failed (using previous config)      │
│ └─ Disk space low                                           │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Exception Hierarchy

```python
class VideoConverterException(Exception):
    """Base exception for all converter errors."""
    pass

class ConfigurationError(VideoConverterException):
    """Configuration file parsing or validation error."""
    pass

class GPUDetectionError(VideoConverterException):
    """GPU detection or initialization error."""
    pass

class ConversionError(VideoConverterException):
    """FFmpeg conversion error."""
    pass

class FileHandlingError(VideoConverterException):
    """File read/write/delete error."""
    pass

class LockfileError(VideoConverterException):
    """Lockfile acquisition or management error."""
    pass

class WatchdogError(VideoConverterException):
    """Directory monitoring error."""
    pass
```

---

## 7. State Management and Lockfile Mechanism

### 7.1 Lockfile Strategy

```
Lockfile Location: /var/lib/videoconverter/converter.lock

Lockfile Contents:
{
  "pid": 12345,
  "timestamp": "2024-12-26T16:51:57Z",
  "hostname": "ubuntu-server",
  "version": "1.0.0"
}

Lockfile Lifecycle:
1. Service starts → Create lockfile with PID
2. Service running → Periodically verify PID is valid
3. Service stops → Remove lockfile
4. Stale lockfile detected → Log warning, remove, restart
```

### 7.2 State Manager Implementation

```python
class StateManager:
    """
    Manages process state and lockfile.
    
    Methods:
        acquire_lock() -> bool: Acquire exclusive lock
        release_lock() -> bool: Release lock
        is_locked() -> bool: Check if locked
        get_lock_info() -> dict: Get lock details
        cleanup_stale_locks() -> None: Remove stale locks
    
    Stale Lock Detection:
        - Check if PID in lockfile is still running
        - Verify process name matches 'python3.12'
        - If stale, log warning and remove
        - Prevent multiple instances from running
    """
```

### 7.3 Conversion State Tracking

```python
class ConversionState:
    """
    Tracks conversion progress and state.
    
    Attributes:
        file_path: Input file path
        output_path: Output file path
        status: pending, in_progress, completed, failed
        start_time: Conversion start timestamp
        end_time: Conversion end timestamp
        error_message: Error details if failed
        retry_count: Number of retry attempts
    
    State Transitions:
        pending → in_progress → completed
        pending → in_progress → failed → pending (retry)
        pending → in_progress → failed (max retries)
    """
```

---

## 8. Security Considerations

### 8.1 File System Security

```
Permission Model:
┌─────────────────────────────────────────────────────────────┐
│ /etc/videoconverter/                                        │
│ ├─ Owner: root:root                                         │
│ ├─ Permissions: 0755 (readable by all)                      │
│ └─ config.yml: 0640 (readable by videoconverter group)      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ /var/lib/videoconverter/                                    │
│ ├─ Owner: videoconverter:videoconverter                     │
│ ├─ Permissions: 0750 (private to service)                   │
│ └─ Contains: lockfile, state database                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ /var/log/videoconverter/                                    │
│ ├─ Owner: videoconverter:videoconverter                     │
│ ├─ Permissions: 0750 (private to service)                   │
│ └─ Contains: structured logs                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ /opt/videoconverter/                                        │
│ ├─ Owner: root:root                                         │
│ ├─ Permissions: 0755 (readable by all)                      │
│ └─ Contains: application code (read-only)                   │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Process Security

```
Systemd Security Hardening:
├─ NoNewPrivileges=true
│  └─ Prevents privilege escalation via setuid binaries
│
├─ PrivateTmp=true
│  └─ Isolated /tmp directory for service
│
├─ ProtectSystem=strict
│  └─ Read-only root filesystem (except specified paths)
│
├─ ProtectHome=true
│  └─ Prevents access to /home and /root
│
├─ ReadWritePaths=/var/lib/videoconverter /var/log/videoconverter /media
│  └─ Explicit whitelist of writable paths
│
└─ User=videoconverter
   └─ Runs as unprivileged system user
```

### 8.3 Input Validation

```python
class InputValidator:
    """
    Validates all user inputs and file paths.
    
    Methods:
        validate_file_path(path) -> bool
        validate_directory_path(path) -> bool
        validate_config_value(key, value) -> bool
        sanitize_ffmpeg_args(args) -> list
    
    Validation Rules:
        - No path traversal (../ sequences)
        - No shell metacharacters in paths
        - File paths must be absolute or relative to config
        - Directory paths must exist and be readable
        - FFmpeg arguments must be from whitelist
    """
```

---

## 9. Data Flow Diagrams

### 9.1 Conversion Process Flow

```
File Detection → Stability Check → Queue → GPU Detection → FFmpeg Execution → Cleanup
     │               │                │          │              │              │
     ▼               ▼                ▼          ▼              ▼              ▼
  Watchdog      Wait 2s for      Priority    Select        Execute      Delete
  detects       file size to     queue       encoder        conversion   original
  .mkv file     stabilize        (FIFO)      based on       with         (if
                                             GPU type       selected     configured)
                                                            encoder
```

### 9.2 Error Recovery Flow

```
Conversion Failure
     │
     ▼
Log Error Details
     │
     ▼
Increment Retry Counter
     │
     ├─ Retry Count < Max?
     │  ├─ YES: Wait retry_delay seconds
     │  │       │
     │  │       ▼
     │  │   Re-queue for conversion
     │  │
     │  └─ NO: Mark as failed
     │         │
     │         ▼
     │     Move to failed directory (optional)
     │     │
     │     ▼
     │     Send notification (if configured)
     │
     └─ Continue processing next file
```

### 9.3 GPU Detection Data Flow

```
Service Start
     │
     ▼
Load Configuration
     │
     ▼
Initialize GPU Detector
     │
     ├─ Check NVIDIA
     │  ├─ nvidia-smi available?
     │  │  ├─ YES: Use hevc_nvenc
     │  │  │       │
     │  │  │       ▼
     │  │  │   Log GPU info
     │  │  │   Return encoder
     │  │  │
     │  │  └─ NO: Continue to next check
     │  │
     │  └─ (Continue to AMD check)
     │
     ├─ Check AMD VA-API
     │  ├─ vainfo available?
     │  │  ├─ YES: Use hevc_vaapi
     │  │  │       │
     │  │  │       ▼
     │  │  │   Log GPU info
     │  │  │   Return encoder
     │  │  │
     │  │  └─ NO: Continue to next check
     │  │
     │  └─ (Continue to Intel check)
     │
     ├─ Check Intel QSV
     │  ├─ hevc_qsv available?
     │  │  ├─ YES: Use hevc_qsv
     │  │  │       │
     │  │  │       ▼
     │  │  │   Log GPU info
     │  │  │   Return encoder
     │  │  │
     │  │  └─ NO: Continue to fallback
     │  │
     │  └─ (Continue to fallback)
     │
     └─ Fallback to CPU
        ├─ Use libx265
        │  │
        │  ▼
        │  Log warning (CPU fallback)
        │  Return encoder
        │
        └─ Service continues with CPU encoding
```

---

## 10. Installation and Deployment Flow

### 10.1 Complete Installation Sequence

```
User runs: sudo ./install.sh
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Validation                                         │
│ ├─ Check root privileges                                   │
│ ├─ Verify Ubuntu 24.04                                     │
│ ├─ Check internet connectivity                             │
│ └─ Verify disk space (min 1GB)                             │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: System Packages                                    │
│ ├─ apt update                                              │
│ ├─ Install Python 3.12                                     │
│ ├─ Install FFmpeg                                          │
│ ├─ Install watchdog library                                │
│ ├─ Detect GPU and install drivers (optional)               │
│ └─ Install system utilities                                │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: User & Group                                       │
│ ├─ Create videoconverter system user                       │
│ ├─ Create videoconverter system group                      │
│ ├─ Set home directory                                      │
│ └─ Restrict shell access                                   │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 4: Directory Structure                                │
│ ├─ Create /etc/videoconverter/                             │
│ ├─ Create /var/lib/videoconverter/                         │
│ ├─ Create /var/log/videoconverter/                         │
│ ├─ Create /opt/videoconverter/                             │
│ └─ Set permissions and ownership                           │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 5: Application Deployment                             │
│ ├─ Copy Python scripts                                     │
│ ├─ Create default config.yml                               │
│ ├─ Set file ownership                                      │
│ └─ Set executable permissions                              │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 6: Systemd Service                                    │
│ ├─ Generate videoconverter.service                         │
│ ├─ Copy to /etc/systemd/system/                            │
│ ├─ systemctl daemon-reload                                 │
│ ├─ systemctl enable videoconverter                         │
│ └─ systemctl start videoconverter                          │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 7: Verification                                       │
│ ├─ Check service status                                    │
│ ├─ Verify GPU detection                                    │
│ ├─ Test file monitoring                                    │
│ ├─ Display installation summary                            │
│ └─ Provide next steps                                      │
└─────────────────────────────────────────────────────────────┘
     │
     ▼
Installation Complete
```

### 10.2 Post-Installation Configuration

```
After Installation:
1. Edit /etc/videoconverter/config.yml
   ├─ Set watch_paths to desired directories
   ├─ Configure conversion parameters
   ├─ Set logging preferences
   └─ Enable/disable features

2. Reload configuration
   └─ systemctl reload videoconverter
      (or restart if reload not supported)

3. Monitor service
   ├─ systemctl status videoconverter
   ├─ journalctl -u videoconverter -f
   └─ tail -f /var/log/videoconverter/converter.log

4. Test conversion
   ├─ Copy test .mkv file to watch directory
   ├─ Monitor logs for conversion progress
   ├─ Verify output file created
   └─ Check original file deleted (if configured)
```

---

## 11. Key Design Decisions

### 11.1 Why Watchdog Over Polling

| Aspect | Watchdog | Polling |
|--------|----------|---------|
| **CPU Usage** | Minimal (event-driven) | Continuous (every N seconds) |
| **Latency** | <100ms | N seconds (configurable) |
| **Scalability** | Handles thousands of files | Limited by polling interval |
| **Complexity** | Moderate | Simple |
| **Reliability** | Kernel-based (inotify) | Application-based |

**Decision**: Use watchdog for real-time, efficient monitoring.

### 11.2 Why Structured JSON Logging

| Aspect | JSON | Text |
|--------|------|------|
| **Parsing** | Machine-readable | Manual parsing required |
| **Searchability** | Excellent (grep, jq) | Limited |
| **Aggregation** | Easy (ELK, Splunk) | Difficult |
| **Context** | Rich metadata | Limited |
| **Performance** | Slightly higher overhead | Minimal |

**Decision**: Use JSON for production-grade observability.

### 11.3 Why Systemd Service

| Aspect | Systemd | Cron | Supervisor |
|--------|---------|------|-----------|
| **Lifecycle** | Full control | Limited | Good |
| **Logging** | Journal integration | File-based | File-based |
| **Dependencies** | Declarative | Manual | Manual |
| **Security** | Hardening options | Limited | Limited |
| **Restart Policy** | Sophisticated | Simple | Good |

**Decision**: Use systemd for production-grade service management.

### 11.4 Why Python 3.12

| Aspect | Python 3.12 | Python 3.10 | Go |
|--------|------------|------------|-----|
| **Availability** | Ubuntu 24.04 native | Backport needed | Not in repos |
| **Development** | Rapid iteration | Slower | Compiled |
| **Libraries** | Rich ecosystem | Good | Limited |
| **Performance** | Good (3.12 optimizations) | Adequate | Excellent |
| **Maintenance** | Long-term support | Shorter | Longer |

**Decision**: Use Python 3.12 for native Ubuntu 24.04 support and rapid development.

---

## 12. Testing Strategy

### 12.1 Unit Testing

```python
# Test GPU Detection
test_nvidia_detection()
test_amd_detection()
test_intel_detection()
test_fallback_to_cpu()

# Test Configuration
test_config_parsing()
test_config_validation()
test_invalid_config_handling()

# Test File Handling
test_file_stability_check()
test_file_deletion()
test_file_permissions()

# Test Logging
test_log_rotation()
test_json_log_format()
test_log_level_filtering()
```

### 12.2 Integration Testing

```python
# End-to-End Conversion
test_mkv_to_mkv_conversion()
test_gpu_acceleration_usage()
test_cpu_fallback_conversion()

# File Monitoring
test_directory_monitoring()
test_multiple_file_handling()
test_concurrent_conversions()

# Error Handling
test_conversion_failure_retry()
test_invalid_file_handling()
test_disk_space_handling()
```

### 12.3 System Testing

```bash
# Installation
test_clean_ubuntu_24_04_installation()
test_upgrade_from_previous_version()
test_gpu_driver_detection()

# Service Management
test_service_start_stop()
test_service_restart_on_failure()
test_configuration_reload()

# Performance
test_cpu_usage_under_load()
test_memory_usage_stability()
test_disk_io_efficiency()
```

---

## 13. Monitoring and Observability

### 13.1 Key Metrics

```
Service Health:
├─ Service uptime
├─ Restart count (last 24h)
├─ Last successful conversion
└─ Current status (running/stopped)

Conversion Metrics:
├─ Files processed (total, daily, hourly)
├─ Conversion success rate
├─ Average conversion time
├─ Failed conversions (with reasons)
└─ Retry attempts

Resource Metrics:
├─ CPU usage (%)
├─ Memory usage (MB)
├─ Disk I/O (MB/s)
└─ GPU utilization (if available)

Error Metrics:
├─ Error count by type
├─ Error rate (errors/hour)
├─ Most common errors
└─ Error recovery success rate
```

### 13.2 Log Queries (using jq)

```bash
# View recent errors
journalctl -u videoconverter -o json | jq 'select(.level=="ERROR")'

# Count conversions by status
tail -f /var/log/videoconverter/converter.log | jq '.status' | sort | uniq -c

# Find slow conversions
tail -f /var/log/videoconverter/converter.log | jq 'select(.duration > 3600)'

# GPU usage analysis
tail -f /var/log/videoconverter/converter.log | jq '.gpu_type' | sort | uniq -c
```

---

## 14. Troubleshooting Guide

### 14.1 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Service won't start | Config file missing | Check `/etc/videoconverter/config.yml` exists |
| GPU not detected | Drivers not installed | Run `nvidia-smi` or `vainfo` to verify |
| Files not being processed | Watchdog not monitoring | Check `watch_paths` in config |
| High CPU usage | CPU fallback active | Install GPU drivers or optimize settings |
| Disk space errors | Output directory full | Check disk space, configure cleanup |
| Permission denied | Incorrect file ownership | Run `chown -R videoconverter:videoconverter /var/lib/videoconverter` |

### 14.2 Debug Mode

```bash
# Enable debug logging
systemctl stop videoconverter
/usr/bin/python3.12 /opt/videoconverter/main.py --debug

# Check service status
systemctl status videoconverter

# View recent logs
journalctl -u videoconverter -n 50 -f

# Check GPU detection
/usr/bin/python3.12 -c "from converter.gpu_detector import GPUDetector; print(GPUDetector().detect())"

# Verify configuration
/usr/bin/python3.12 -c "from converter.config import Config; Config.load('/etc/videoconverter/config.yml')"
```

---

## 15. Future Enhancements

### 15.1 Planned Features

- [ ] Web UI for monitoring and configuration
- [ ] REST API for remote control
- [ ] Email/webhook notifications
- [ ] Conversion queue management UI
- [ ] Performance analytics dashboard
- [ ] Multi-format output support
- [ ] Subtitle handling
- [ ] Metadata preservation
- [ ] Distributed conversion (multiple machines)
- [ ] Cloud storage integration (S3, GCS)

### 15.2 Performance Optimizations

- [ ] Hardware-accelerated audio encoding
- [ ] Parallel subtitle processing
- [ ] Adaptive bitrate selection
- [ ] Caching of conversion profiles
- [ ] GPU memory optimization
- [ ] Batch processing optimization

---

## 16. Conclusion

This architecture provides a robust, production-grade video converter solution for Ubuntu 24.04 with:

✓ **Reliability**: Systemd service management with restart policies
✓ **Performance**: GPU acceleration with intelligent fallback
✓ **Observability**: Structured JSON logging with rotation
✓ **Security**: Hardened systemd configuration and file permissions
✓ **Maintainability**: Clear module separation and error handling
✓ **Scalability**: Concurrent conversion support with resource limits
✓ **Usability**: Turn-key installation with sensible defaults

The design follows POSIX/Linux best practices and is ready for implementation in subsequent tasks.
