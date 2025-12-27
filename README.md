# Video Converter Service

A production-grade, GPU-accelerated video converter service for Ubuntu 24.04 with automatic hardware detection, real-time directory monitoring, and robust error handling.

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Prerequisites](#prerequisites)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [GPU Detection Logic](#gpu-detection-logic)
7. [Usage](#usage)
8. [Testing](#testing)
9. [Troubleshooting](#troubleshooting)
10. [Logging](#logging)
11. [Performance Tuning](#performance-tuning)
12. [Security Considerations](#security-considerations)
13. [Uninstallation](#uninstallation)
14. [Advanced Topics](#advanced-topics)
15. [Support and Contributing](#support-and-contributing)

---

## Overview

The Video Converter Service is a turn-key solution for automated video encoding on Ubuntu 24.04. It provides:

- **Continuous Operation**: Runs as a systemd service with automatic restart on failure
- **Real-Time Monitoring**: Watches configured directories for new video files using the watchdog library
- **Intelligent GPU Detection**: Automatically detects and utilizes available GPU hardware with graceful CPU fallback
- **H.265/HEVC Conversion**: Modern video codec for superior compression and quality
- **Structured Logging**: JSON-formatted logs with automatic rotation and retention
- **Safe File Handling**: Only deletes original files after successful conversion verification
- **Graceful Error Handling**: Automatic retry logic with exponential backoff

### Target Platform

- **Operating System**: Ubuntu 24.04 LTS (or compatible derivatives)
- **Python Version**: Python 3.12 (native to Ubuntu 24.04)
- **FFmpeg**: Latest version with codec support
- **GPU Support**: NVIDIA, AMD, Intel (optional)

### Quick Value Proposition

Convert your video library to modern H.265/HEVC format automatically with GPU acceleration, reducing file sizes by 40-50% while maintaining quality. Set it and forget it—the service handles everything from file detection to cleanup.

---

## Features

### Core Capabilities

| Feature | Description |
|---------|-------------|
| **Continuous Service** | Runs as systemd service with automatic restart policies |
| **Real-Time Monitoring** | Watchdog-based directory monitoring for instant file detection |
| **GPU Acceleration** | Automatic detection and utilization of NVIDIA, AMD, or Intel GPUs |
| **H.265/HEVC Encoding** | Modern video codec with superior compression (40-50% smaller files) |
| **Structured JSON Logging** | Machine-readable logs with automatic rotation and 14-day retention |
| **Safe Deletion** | Original files only deleted after successful conversion verification |
| **Error Recovery** | Automatic retry with exponential backoff (up to 3 attempts by default) |
| **Concurrent Processing** | Configurable worker threads for parallel conversions |
| **Security Hardening** | Systemd security features, unprivileged user, restricted file permissions |
| **Configuration Reload** | Update settings without restarting the service |

### Technical Highlights

- **Watchdog Library**: Event-driven file monitoring (inotify-based) instead of polling
- **File Stability Detection**: Waits for file write completion before processing
- **Graceful Shutdown**: Proper signal handling (SIGTERM, SIGINT) for clean exits
- **Resource Limits**: CPU quota (80%), memory limit (2GB), task limits
- **Lockfile Mechanism**: Prevents multiple instances from running simultaneously
- **Comprehensive Error Classification**: Fatal, recoverable, and warning-level errors

---

## Prerequisites

### System Requirements

- **Ubuntu 24.04 LTS** or compatible derivative
- **Root or sudo access** for installation
- **Minimum 1GB free disk space** for installation and temporary files
- **Sufficient storage** for video conversions (typically 2-3x source file size during conversion)

### Optional Hardware

- **NVIDIA GPU**: NVIDIA driver and CUDA toolkit (for hevc_nvenc encoder)
- **AMD GPU**: VA-API drivers (for hevc_vaapi encoder)
- **Intel GPU**: Intel Media Driver (for hevc_qsv encoder)

> **Note**: GPU is optional. The service will automatically fall back to CPU encoding (libx265) if no GPU is detected.

### Software Dependencies

The installation script automatically installs:

- Python 3.12 runtime
- FFmpeg with codec support
- Watchdog library (directory monitoring)
- PyYAML (configuration parsing)
- System utilities (curl, jq, etc.)

---

## Installation

### Quick Start

```bash
# Clone or download the repository
cd /path/to/video-converter

# Run the installation script with sudo
sudo ./install_videoconverter.sh
```

### Step-by-Step Installation

#### 1. Verify Prerequisites

```bash
# Check Ubuntu version
lsb_release -a

# Verify internet connectivity
ping -c 1 8.8.8.8

# Check available disk space
df -h /
```

#### 2. Run Installation Script

```bash
# Basic installation (uses default user/group: videoconverter)
sudo ./install_videoconverter.sh

# Custom user and group
sudo ./install_videoconverter.sh --user myuser --group mygroup

# Show help
sudo ./install_videoconverter.sh --help
```

#### 3. Installation Phases

The script performs the following phases:

| Phase | Action |
|-------|--------|
| **1. Validation** | Checks root privileges, Ubuntu version, disk space |
| **2. Packages** | Installs Python, FFmpeg, watchdog, and optional GPU drivers |
| **3. User/Group** | Creates unprivileged system user and group |
| **4. Directories** | Creates `/etc/videoconverter`, `/var/lib/videoconverter`, `/var/log/videoconverter`, `/var/run/videoconverter` |
| **5. Configuration** | Deploys default `config.yml` |
| **6. Environment** | Creates environment file with paths |
| **7. Python Script** | Copies converter script to `/usr/local/bin/videoconverter` |
| **8. Systemd Service** | Installs and enables systemd service unit |
| **9. Verification** | Verifies service is running and GPU detection works |

#### 4. Verification

After installation, verify the service is running:

```bash
# Check service status
sudo systemctl status videoconverter

# View recent logs
sudo journalctl -u videoconverter -n 20

# Check GPU detection
sudo journalctl -u videoconverter | grep -i gpu
```

### Custom Installation

If you prefer manual installation:

1. Create user and group:
   ```bash
   sudo groupadd --system videoconverter
   sudo useradd --system --group videoconverter \
     --home-dir /var/lib/videoconverter \
     --shell /usr/sbin/nologin \
     --comment "Video Converter Service" videoconverter
   ```

2. Create directories:
   ```bash
   sudo mkdir -p /etc/videoconverter /var/lib/videoconverter /var/log/videoconverter /var/run/videoconverter
   sudo chown videoconverter:videoconverter /var/lib/videoconverter /var/log/videoconverter /var/run/videoconverter
   sudo chmod 750 /var/lib/videoconverter /var/log/videoconverter /var/run/videoconverter
   ```

3. Copy configuration:
   ```bash
   sudo cp config.yml /etc/videoconverter/config.yml
   sudo chmod 644 /etc/videoconverter/config.yml
   ```

4. Copy Python script:
   ```bash
   sudo cp videoconverter /usr/local/bin/videoconverter
   sudo chmod 755 /usr/local/bin/videoconverter
   ```

5. Install systemd service:
   ```bash
   sudo cp videoconverter.service.template /etc/systemd/system/videoconverter.service
   sudo systemctl daemon-reload
   sudo systemctl enable videoconverter
   sudo systemctl start videoconverter
   ```

---

## Configuration

### Configuration File Location

The main configuration file is located at:

```
/etc/videoconverter/config.yml
```

Edit this file to customize service behavior. Changes can be reloaded without restarting:

```bash
sudo systemctl reload videoconverter
```

### Configuration Structure

#### Service Settings

```yaml
log_level: INFO                    # DEBUG, INFO, WARNING, ERROR
max_workers: 2                     # Concurrent conversion threads
conversion_timeout: 3600           # FFmpeg timeout in seconds (0 = no timeout)
```

#### Directory Monitoring

```yaml
watch_directories:
  - path: /home/user/Videos/ToConvert
    recursive: true
    enabled: true
  - path: /mnt/media/incoming
    recursive: false
    enabled: true

file_patterns:
  - "*.mkv"
  - "*.mp4"
  - "*.avi"

exclude_patterns:
  - "*sample*"
  - "*temp*"
```

#### Logging Configuration

```yaml
logging:
  log_dir: /var/log/videoconverter
  log_format: json                 # json or text
  max_log_age_days: 14             # Retention period
  log_rotation: true               # Enable daily rotation
```

#### File Handling

```yaml
file_handling:
  delete_original: true            # Delete source after successful conversion
  preserve_permissions: true       # Keep original file permissions
  preserve_timestamps: false       # Keep original modification time
  backup_original: false           # Create .backup before conversion
```

#### Conversion Parameters

```yaml
conversion:
  video_codec: "auto"              # hevc_nvenc, hevc_vaapi, hevc_qsv, libx265
  video_bitrate: "auto"            # "8M", "10M", or "auto" for CRF
  crf: 28                          # Quality (0-51, lower = better)
  audio_codec: "aac"               # aac, libmp3lame, libopus, libvorbis
  audio_bitrate: "128k"            # Audio bitrate
  output_format: "mkv"             # mkv or mp4
```

#### Error Handling

```yaml
error_handling:
  max_retries: 3                   # Retry attempts for failed conversions
  retry_delay_seconds: 60          # Delay between retries (exponential backoff)
  skip_on_error: false             # Skip file after max retries
```

#### GPU Configuration

```yaml
gpu:
  force_encoder: ""                # Force specific encoder (empty = auto-detect)
  device_id: 0                     # GPU device index for multi-GPU systems
  enabled: true                    # Enable GPU acceleration
```

### Example Configurations

#### High-Quality Conversion (Slower)

```yaml
conversion:
  crf: 23                          # Higher quality
  preset: slow                     # Slower encoding
  audio_bitrate: "192k"            # Better audio quality
```

#### Fast Conversion (Lower Quality)

```yaml
conversion:
  crf: 32                          # Lower quality
  preset: faster                   # Faster encoding
  audio_bitrate: "96k"             # Lower audio quality
```

#### CPU-Only Mode

```yaml
gpu:
  force_encoder: "cpu"             # Force libx265 CPU encoding
  enabled: false                   # Disable GPU acceleration
```

#### Batch Processing

```yaml
service:
  max_workers: 4                   # Process 4 files simultaneously
  conversion_timeout: 7200         # 2-hour timeout for large files
```

---

## GPU Detection Logic

The service automatically detects available GPU hardware and selects the optimal encoder. The detection sequence is:

### Detection Sequence

```
1. NVIDIA GPU (hevc_nvenc)
   └─ Check: nvidia-smi --query-gpu=name
   └─ Encoder: hevc_nvenc
   └─ Performance: Excellent (dedicated hardware)

2. AMD VA-API (hevc_vaapi)
   └─ Check: vainfo | grep -i hevc
   └─ Encoder: hevc_vaapi
   └─ Performance: Good (hardware-accelerated)

3. Intel QSV (hevc_qsv)
   └─ Check: ffmpeg -codecs | grep hevc_qsv
   └─ Encoder: hevc_qsv
   └─ Performance: Good (hardware-accelerated)

4. CPU Fallback (libx265)
   └─ Encoder: libx265
   └─ Performance: Adequate (software encoding)
```

### Verifying GPU Detection

Check which GPU was detected:

```bash
# View GPU detection in logs
sudo journalctl -u videoconverter | grep -i "gpu\|encoder"

# Example output:
# GPU Detection: NVIDIA GPU detected
# Selected Encoder: hevc_nvenc
```

### Forcing CPU-Only Mode

To disable GPU acceleration and use CPU encoding:

```bash
# Edit configuration
sudo nano /etc/videoconverter/config.yml

# Set:
gpu:
  force_encoder: "cpu"
  enabled: false

# Reload configuration
sudo systemctl reload videoconverter
```

### GPU Driver Installation

#### NVIDIA GPU

```bash
# Install NVIDIA driver
sudo apt update
sudo apt install nvidia-driver-open nvidia-utils

# Verify installation
nvidia-smi
```

#### AMD GPU

```bash
# Install VA-API drivers
sudo apt update
sudo apt install libva-dev libva-glx2 vainfo

# Verify installation
vainfo | grep -i hevc
```

#### Intel GPU

```bash
# Install Intel Media Driver
sudo apt update
sudo apt install intel-media-driver libmfx1

# Verify installation
ffmpeg -codecs | grep hevc_qsv
```

---

## Usage

### Starting the Service

```bash
# Start the service
sudo systemctl start videoconverter

# Enable service to start on boot
sudo systemctl enable videoconverter

# Verify service is running
sudo systemctl status videoconverter
```

### Stopping the Service

```bash
# Stop the service gracefully
sudo systemctl stop videoconverter

# Disable service from starting on boot
sudo systemctl disable videoconverter
```

### Checking Service Status

```bash
# View current status
sudo systemctl status videoconverter

# Check if service is active
sudo systemctl is-active videoconverter

# Check if service is enabled
sudo systemctl is-enabled videoconverter
```

### Viewing Logs

#### Systemd Journal Logs

```bash
# View recent logs (last 20 lines)
sudo journalctl -u videoconverter -n 20

# Follow logs in real-time
sudo journalctl -u videoconverter -f

# View logs since last boot
sudo journalctl -u videoconverter -b

# View logs with full details
sudo journalctl -u videoconverter -o verbose

# View only errors
sudo journalctl -u videoconverter -p err
```

#### Application Logs

```bash
# View conversion logs
tail -f /var/log/videoconverter/converter.log

# View all log files
ls -lah /var/log/videoconverter/

# Search logs for specific file
grep "filename.mkv" /var/log/videoconverter/converter.log

# Parse JSON logs with jq
tail -f /var/log/videoconverter/converter.log | jq '.message'
```

### Restarting the Service

```bash
# Restart the service
sudo systemctl restart videoconverter

# Restart and view logs
sudo systemctl restart videoconverter && sudo journalctl -u videoconverter -f
```

### Reloading Configuration

```bash
# Reload configuration without restarting
sudo systemctl reload videoconverter

# Verify configuration was reloaded
sudo journalctl -u videoconverter | grep -i "config\|reload"
```

### Basic Workflow

1. **Configure watch directories** in `/etc/videoconverter/config.yml`
2. **Start the service**: `sudo systemctl start videoconverter`
3. **Copy video files** to configured watch directories
4. **Monitor progress**: `sudo journalctl -u videoconverter -f`
5. **Check results**: Converted files appear in output directory

---

## Testing

### Installation Verification

After installation, verify everything is working:

```bash
# 1. Check service is running
sudo systemctl status videoconverter

# 2. Verify GPU detection
sudo journalctl -u videoconverter | grep -i gpu

# 3. Check configuration is valid
sudo python3 -c "import yaml; yaml.safe_load(open('/etc/videoconverter/config.yml'))"

# 4. Verify directories exist
ls -la /etc/videoconverter /var/lib/videoconverter /var/log/videoconverter
```

### Manual Conversion Test

Test the converter with a sample video file:

```bash
# 1. Create test directory
mkdir -p ~/test_videos/input ~/test_videos/output

# 2. Copy a test video file
cp /path/to/test.mkv ~/test_videos/input/

# 3. Update configuration to watch test directory
sudo nano /etc/videoconverter/config.yml
# Set watch_directories to ~/test_videos/input

# 4. Reload configuration
sudo systemctl reload videoconverter

# 5. Monitor conversion
sudo journalctl -u videoconverter -f

# 6. Check output
ls -lah ~/test_videos/output/
```

### Dry-Run Mode

Test configuration without actual conversions:

```bash
# Edit configuration
sudo nano /etc/videoconverter/config.yml

# Enable dry-run mode
advanced:
  enable_dry_run: true

# Reload service
sudo systemctl reload videoconverter

# Monitor logs (no actual conversions will occur)
sudo journalctl -u videoconverter -f

# Disable dry-run when done
# Set enable_dry_run: false
# Reload service
```

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Edit configuration
sudo nano /etc/videoconverter/config.yml

# Set log level to DEBUG
log_level: DEBUG

# Reload service
sudo systemctl reload videoconverter

# View detailed logs
sudo journalctl -u videoconverter -f
```

### Performance Testing

Test conversion speed and resource usage:

```bash
# Monitor resource usage during conversion
watch -n 1 'ps aux | grep videoconverter'

# Monitor GPU usage (NVIDIA)
watch -n 1 nvidia-smi

# Monitor disk I/O
iostat -x 1

# Check conversion time in logs
grep "duration" /var/log/videoconverter/converter.log | jq '.duration'
```

---

## Troubleshooting

### Common Issues and Solutions

#### Service Won't Start

**Symptom**: `systemctl status videoconverter` shows failed state

**Solutions**:

```bash
# 1. Check configuration file exists
sudo test -f /etc/videoconverter/config.yml && echo "Config exists" || echo "Config missing"

# 2. Validate YAML syntax
sudo python3 -c "import yaml; yaml.safe_load(open('/etc/videoconverter/config.yml'))"

# 3. Check service logs
sudo journalctl -u videoconverter -n 50

# 4. Verify permissions
sudo ls -la /etc/videoconverter /var/lib/videoconverter /var/log/videoconverter

# 5. Check if another instance is running
sudo ps aux | grep videoconverter
```

#### Files Not Being Converted

**Symptom**: Files in watch directory are not being processed

**Solutions**:

```bash
# 1. Verify watch directories are configured
sudo grep -A 5 "watch_directories" /etc/videoconverter/config.yml

# 2. Check directory permissions
sudo ls -la /path/to/watch/directory

# 3. Verify file patterns match
sudo grep -A 3 "file_patterns" /etc/videoconverter/config.yml

# 4. Check if service is monitoring
sudo journalctl -u videoconverter | grep -i "watch\|monitor"

# 5. Test with a simple file
touch /path/to/watch/directory/test.mkv
sudo journalctl -u videoconverter -f
```

#### GPU Not Detected

**Symptom**: Service uses CPU encoding instead of GPU

**Solutions**:

```bash
# 1. Check GPU detection in logs
sudo journalctl -u videoconverter | grep -i gpu

# 2. Verify GPU drivers are installed
nvidia-smi                    # NVIDIA
vainfo | grep hevc            # AMD
ffmpeg -codecs | grep hevc_qsv # Intel

# 3. Check GPU is accessible to service user
sudo -u videoconverter nvidia-smi

# 4. Force GPU encoder in configuration
sudo nano /etc/videoconverter/config.yml
# Set: force_encoder: "nvidia"  # or "amd", "intel"

# 5. Reload service
sudo systemctl reload videoconverter
```

#### Permission Errors

**Symptom**: Logs show "Permission denied" errors

**Solutions**:

```bash
# 1. Fix directory ownership
sudo chown -R videoconverter:videoconverter /var/lib/videoconverter
sudo chown -R videoconverter:videoconverter /var/log/videoconverter

# 2. Fix directory permissions
sudo chmod 750 /var/lib/videoconverter /var/log/videoconverter

# 3. Fix watch directory permissions
sudo chmod 755 /path/to/watch/directory

# 4. Verify service user can read watch directory
sudo -u videoconverter test -r /path/to/watch/directory && echo "Readable" || echo "Not readable"

# 5. Restart service
sudo systemctl restart videoconverter
```

#### Disk Space Issues

**Symptom**: Conversions fail with "No space left on device"

**Solutions**:

```bash
# 1. Check available disk space
df -h

# 2. Check log directory size
du -sh /var/log/videoconverter

# 3. Clean old logs manually
sudo find /var/log/videoconverter -name "*.log.*" -mtime +14 -delete

# 4. Check output directory size
du -sh /path/to/output/directory

# 5. Configure log rotation in config.yml
sudo nano /etc/videoconverter/config.yml
# Adjust: max_log_age_days: 7  # Reduce retention

# 6. Reload service
sudo systemctl reload videoconverter
```

#### FFmpeg Errors

**Symptom**: Conversion fails with FFmpeg error messages

**Solutions**:

```bash
# 1. Check FFmpeg is installed
ffmpeg -version

# 2. Verify codec support
ffmpeg -codecs | grep hevc

# 3. Test FFmpeg directly
ffmpeg -i /path/to/input.mkv -c:v libx265 -crf 28 /tmp/test.mkv

# 4. Check FFmpeg logs
sudo journalctl -u videoconverter | grep -i ffmpeg

# 5. Enable debug logging
sudo nano /etc/videoconverter/config.yml
# Set: log_level: DEBUG
sudo systemctl reload videoconverter

# 6. Check for corrupted input files
ffmpeg -v error -i /path/to/file.mkv -f null -
```

### Debug Mode

Enable comprehensive debugging:

```bash
# 1. Stop the service
sudo systemctl stop videoconverter

# 2. Run in foreground with debug output
sudo -u videoconverter /usr/local/bin/videoconverter --debug

# 3. Or enable debug logging in config
sudo nano /etc/videoconverter/config.yml
# Set: log_level: DEBUG

# 4. Restart and monitor
sudo systemctl restart videoconverter
sudo journalctl -u videoconverter -f
```

### Checking Service Status

```bash
# Comprehensive status check
echo "=== Service Status ==="
sudo systemctl status videoconverter

echo "=== Recent Logs ==="
sudo journalctl -u videoconverter -n 20

echo "=== GPU Detection ==="
sudo journalctl -u videoconverter | grep -i gpu | tail -5

echo "=== Active Conversions ==="
sudo ps aux | grep videoconverter | grep -v grep

echo "=== Disk Usage ==="
df -h /var/log/videoconverter /var/lib/videoconverter
```

### Resetting the Service

If the service is in a bad state:

```bash
# 1. Stop the service
sudo systemctl stop videoconverter

# 2. Remove lockfile
sudo rm -f /var/run/videoconverter/videoconverter.lock

# 3. Clear state database (if exists)
sudo rm -f /var/lib/videoconverter/state.db

# 4. Restart the service
sudo systemctl start videoconverter

# 5. Verify it's running
sudo systemctl status videoconverter
```

---

## Logging

### Log Location

All logs are stored in:

```
/var/log/videoconverter/
```

### Log Format

Logs are stored in JSON format for easy parsing and analysis:

```json
{
  "timestamp": "2024-12-26T16:51:57Z",
  "level": "INFO",
  "component": "ffmpeg_handler",
  "message": "Conversion completed successfully",
  "context": {
    "input_file": "/home/user/Videos/test.mkv",
    "output_file": "/home/user/Videos/converted/test.mkv",
    "duration": 1234.5,
    "encoder": "hevc_nvenc"
  }
}
```

### Log Rotation

Logs are automatically rotated based on:

- **Max file size**: 10MB
- **Retention period**: 14 days
- **Backup count**: 14 files
- **Compression**: Older logs are gzip-compressed

Log file structure:

```
/var/log/videoconverter/
├── converter.log              (current)
├── converter.log.1            (yesterday)
├── converter.log.2            (2 days ago)
├── converter.log.3.gz         (3+ days ago, compressed)
└── converter.log.14.gz        (14 days ago, oldest)
```

### Querying Logs with jq

Parse and analyze JSON logs:

```bash
# View all messages
tail -f /var/log/videoconverter/converter.log | jq '.message'

# Filter by log level
tail -f /var/log/videoconverter/converter.log | jq 'select(.level=="ERROR")'

# View conversion duration
tail -f /var/log/videoconverter/converter.log | jq '.context.duration'

# Count conversions by status
tail -f /var/log/videoconverter/converter.log | jq '.context.status' | sort | uniq -c

# Find slow conversions (> 1 hour)
tail -f /var/log/videoconverter/converter.log | jq 'select(.context.duration > 3600)'

# View GPU usage
tail -f /var/log/videoconverter/converter.log | jq '.context.encoder' | sort | uniq -c

# Get error details
tail -f /var/log/videoconverter/converter.log | jq 'select(.level=="ERROR") | {message, error: .context.error}'
```

### Log Levels

| Level | Usage | Example |
|-------|-------|---------|
| **DEBUG** | Detailed diagnostic information | Variable values, function calls |
| **INFO** | General informational messages | Service started, file processed |
| **WARNING** | Warning messages for recoverable issues | GPU not available, file skipped |
| **ERROR** | Error messages for failures | Conversion failed, permission denied |
| **CRITICAL** | Critical failures requiring immediate attention | Service cannot start, fatal error |

### Monitoring Logs

```bash
# Real-time monitoring
sudo journalctl -u videoconverter -f

# Monitor application logs
tail -f /var/log/videoconverter/converter.log

# Monitor both simultaneously
sudo bash -c 'journalctl -u videoconverter -f & tail -f /var/log/videoconverter/converter.log'

# Search for specific patterns
sudo journalctl -u videoconverter | grep "ERROR"
grep "filename.mkv" /var/log/videoconverter/converter.log
```

---

## Performance Tuning

### Adjusting Concurrent Workers

Control how many videos are converted simultaneously:

```yaml
service:
  max_workers: 2  # Default: 2
```

**Recommendations**:

- **1 worker**: Single conversion at a time (low resource usage)
- **2 workers**: Dual conversions (balanced, recommended)
- **4+ workers**: Multiple conversions (high resource usage)

```bash
# Example: Set to 4 workers
sudo nano /etc/videoconverter/config.yml
# Change: max_workers: 4
sudo systemctl reload videoconverter
```

### Choosing Preset Values

The preset controls the speed vs. quality tradeoff:

| Preset | Speed | Quality | Use Case |
|--------|-------|---------|----------|
| **ultrafast** | Fastest | Lowest | Quick preview |
| **superfast** | Very fast | Low | Fast processing |
| **veryfast** | Fast | Medium | Balanced |
| **faster** | Medium-fast | Medium-high | Balanced |
| **fast** | Medium | High | Recommended |
| **medium** | Slow | Very high | Default |
| **slow** | Very slow | Excellent | High quality |
| **slower** | Slowest | Excellent | Archival |
| **veryslow** | Extremely slow | Maximum | Maximum quality |

```yaml
conversion:
  preset: medium  # Default
```

### CRF (Quality) Settings

The Constant Rate Factor (CRF) controls quality:

```yaml
conversion:
  crf: 28  # Default (0-51, lower = better)
```

**Quality Guidelines**:

- **0-18**: Visually lossless (very large files)
- **18-28**: High quality (recommended: 23-28)
- **28**: Default, good quality with reasonable file size
- **28-35**: Medium quality, smaller files
- **35-51**: Low quality, very small files

```bash
# Example: High-quality conversion
sudo nano /etc/videoconverter/config.yml
# Change: crf: 23
sudo systemctl reload videoconverter
```

### GPU-Specific Optimization

#### NVIDIA GPU

```yaml
conversion:
  video_codec: "auto"  # Will use hevc_nvenc
  preset: fast         # NVIDIA presets: default, fast, slow
```

#### AMD GPU

```yaml
conversion:
  video_codec: "auto"  # Will use hevc_vaapi
  preset: medium       # Standard presets apply
```

#### Intel GPU

```yaml
conversion:
  video_codec: "auto"  # Will use hevc_qsv
  preset: medium       # Standard presets apply
```

### Monitoring Resource Usage

```bash
# Monitor CPU usage
top -p $(pgrep -f videoconverter)

# Monitor memory usage
ps aux | grep videoconverter | grep -v grep

# Monitor GPU usage (NVIDIA)
watch -n 1 nvidia-smi

# Monitor disk I/O
iostat -x 1

# Monitor network (if using remote storage)
iftop
```

### Performance Benchmarking

Test conversion speed:

```bash
# 1. Create test file (1GB)
dd if=/dev/zero of=/tmp/test.mkv bs=1M count=1024

# 2. Time the conversion
time ffmpeg -i /tmp/test.mkv -c:v hevc_nvenc -crf 28 /tmp/output.mkv

# 3. Compare with CPU
time ffmpeg -i /tmp/test.mkv -c:v libx265 -crf 28 /tmp/output_cpu.mkv

# 4. Check file sizes
ls -lh /tmp/test.mkv /tmp/output.mkv /tmp/output_cpu.mkv
```

---

## Security Considerations

### Service User and Permissions

The service runs as an unprivileged system user:

```bash
# Service user details
id videoconverter

# User home directory
ls -la /var/lib/videoconverter

# User shell (nologin - cannot login)
grep videoconverter /etc/passwd
```

### File Permissions

Proper file permissions prevent unauthorized access:

```
/etc/videoconverter/
├── Owner: root:root
├── Permissions: 0755 (readable by all)
└── config.yml: 0644 (readable by all)

/var/lib/videoconverter/
├── Owner: videoconverter:videoconverter
├── Permissions: 0750 (private to service)
└── Contains: lockfile, state database

/var/log/videoconverter/
├── Owner: videoconverter:videoconverter
├── Permissions: 0750 (private to service)
└── Contains: structured logs

/opt/videoconverter/ (if applicable)
├── Owner: root:root
├── Permissions: 0755 (readable by all)
└── Contains: application code (read-only)
```

### Configuration File Security

Protect sensitive configuration:

```bash
# View current permissions
ls -la /etc/videoconverter/config.yml

# Ensure only root can write
sudo chmod 644 /etc/videoconverter/config.yml

# Verify ownership
sudo chown root:root /etc/videoconverter/config.yml
```

### Log File Access

Logs contain sensitive information:

```bash
# View log permissions
ls -la /var/log/videoconverter/

# Restrict access to service user only
sudo chmod 750 /var/log/videoconverter/

# View logs as root
sudo tail -f /var/log/videoconverter/converter.log

# View logs as service user
sudo -u videoconverter tail -f /var/log/videoconverter/converter.log
```

### Systemd Security Hardening

The service uses systemd security features:

| Setting | Purpose |
|---------|---------|
| **NoNewPrivileges=true** | Prevents privilege escalation via setuid binaries |
| **PrivateTmp=true** | Isolated /tmp directory for service |
| **ProtectSystem=strict** | Read-only root filesystem (except specified paths) |
| **ProtectHome=true** | Prevents access to /home and /root |
| **ReadWritePaths** | Explicit whitelist of writable paths |
| **User=videoconverter** | Runs as unprivileged system user |

View security settings:

```bash
# Check service security settings
sudo systemctl show -p ProtectSystem videoconverter
sudo systemctl show -p ProtectHome videoconverter
sudo systemctl show -p NoNewPrivileges videoconverter
```

### Best Practices

1. **Restrict watch directories**: Only monitor directories you trust
2. **Use strong file permissions**: Ensure only authorized users can access files
3. **Monitor logs regularly**: Check for suspicious activity
4. **Keep software updated**: Regularly update FFmpeg and system packages
5. **Use configuration management**: Track changes to configuration files
6. **Backup important files**: Before enabling `delete_original: true`
7. **Audit access**: Monitor who accesses the service and logs

---

## Uninstallation

### Complete Removal

To completely remove the Video Converter Service:

```bash
# 1. Stop the service
sudo systemctl stop videoconverter

# 2. Disable service from auto-start
sudo systemctl disable videoconverter

# 3. Remove systemd service file
sudo rm /etc/systemd/system/videoconverter.service

# 4. Reload systemd
sudo systemctl daemon-reload

# 5. Remove application files
sudo rm /usr/local/bin/videoconverter

# 6. Remove configuration directory
sudo rm -rf /etc/videoconverter

# 7. Remove log directory (optional - keep for archival)
sudo rm -rf /var/log/videoconverter

# 8. Remove state directory
sudo rm -rf /var/lib/videoconverter

# 9. Remove runtime directory
sudo rm -rf /var/run/videoconverter

# 10. Remove service user and group
sudo userdel videoconverter
sudo groupdel videoconverter
```

### Preserving Configuration and Logs

To keep configuration and logs for future reference:

```bash
# 1. Backup configuration
sudo cp -r /etc/videoconverter ~/videoconverter-config-backup

# 2. Backup logs
sudo cp -r /var/log/videoconverter ~/videoconverter-logs-backup

# 3. Change ownership to current user
sudo chown -R $USER:$USER ~/videoconverter-*

# 4. Then proceed with uninstallation (skip steps 6-7)
```

### Partial Removal

To keep the service but remove only logs:

```bash
# Remove old logs only
sudo find /var/log/videoconverter -name "*.log.*" -delete

# Or remove all logs
sudo rm -rf /var/log/videoconverter/*
```

---

## Advanced Topics

### Custom FFmpeg Parameters

Add custom FFmpeg arguments to the configuration:

```yaml
conversion:
  extra_args:
    - "-movflags"
    - "+faststart"
    - "-metadata"
    - "title=My Video"
```

### Monitoring with External Tools

Integrate with monitoring systems:

```bash
# Export metrics to Prometheus
curl -s http://localhost:9090/metrics

# Send logs to ELK Stack
sudo journalctl -u videoconverter -o json | curl -X POST -d @- http://elasticsearch:9200/_bulk

# Monitor with Grafana
# Create dashboard using JSON logs from /var/log/videoconverter/
```

### Integration with Other Services

#### Webhook Notifications

Configure webhook notifications on conversion completion:

```yaml
error_handling:
  webhook_url: "https://example.com/webhook"
```

#### Email Notifications

Configure email alerts for errors:

```yaml
error_handling:
  notify_email: "admin@example.com"
```

### Backup and Recovery Procedures

#### Backup Configuration

```bash
# Backup configuration
sudo tar -czf ~/videoconverter-backup.tar.gz /etc/videoconverter

# Restore configuration
sudo tar -xzf ~/videoconverter-backup.tar.gz -C /
```

#### Backup Logs

```bash
# Archive logs
sudo tar -czf ~/videoconverter-logs-$(date +%Y%m%d).tar.gz /var/log/videoconverter

# Compress old logs
sudo gzip /var/log/videoconverter/converter.log.*
```

#### Recovery Procedures

```bash
# Restore from backup
sudo systemctl stop videoconverter
sudo tar -xzf ~/videoconverter-backup.tar.gz -C /
sudo systemctl start videoconverter

# Verify restoration
sudo systemctl status videoconverter
```

### Performance Profiling

Enable performance profiling:

```yaml
advanced:
  profile: true
```

Then analyze profiling data:

```bash
# View profiling results
grep "profile" /var/log/videoconverter/converter.log | jq '.context.profile'
```

### Multi-Instance Setup

Run multiple instances for distributed processing:

```bash
# Create second instance
sudo cp /etc/systemd/system/videoconverter.service \
  /etc/systemd/system/videoconverter-2.service

# Edit second instance
sudo nano /etc/systemd/system/videoconverter-2.service
# Change: ExecStart=/usr/local/bin/videoconverter --instance 2

# Start both instances
sudo systemctl start videoconverter videoconverter-2
```

---

## Support and Contributing

### Reporting Issues

If you encounter issues:

1. **Collect diagnostic information**:
   ```bash
   sudo journalctl -u videoconverter -n 100 > logs.txt
   cat /etc/videoconverter/config.yml > config.txt
   systemctl status videoconverter > status.txt
   ```

2. **Check existing issues**: Search GitHub issues for similar problems

3. **Create detailed bug report** with:
   - Ubuntu version
   - Service version
   - Configuration (sanitized)
   - Error logs
   - Steps to reproduce

### Contributing Improvements

Contributions are welcome! To contribute:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes** with clear commit messages
4. **Test thoroughly** before submitting
5. **Submit a pull request** with description of changes

### License

This project is licensed under the MIT License. See LICENSE file for details.

### Additional Resources

- **Architecture Documentation**: See [`ARCHITECTURE.md`](ARCHITECTURE.md) for detailed system design
- **Configuration Reference**: See [`config.yml`](config.yml) for all available options
- **Installation Script**: See [`install_videoconverter.sh`](install_videoconverter.sh) for installation details
- **Systemd Service**: See [`videoconverter.service.template`](videoconverter.service.template) for service configuration

---

## Quick Reference

### Essential Commands

```bash
# Service Management
sudo systemctl start videoconverter      # Start service
sudo systemctl stop videoconverter       # Stop service
sudo systemctl restart videoconverter    # Restart service
sudo systemctl status videoconverter     # Check status
sudo systemctl enable videoconverter     # Enable on boot
sudo systemctl disable videoconverter    # Disable on boot

# Logging
sudo journalctl -u videoconverter -f     # Follow logs
tail -f /var/log/videoconverter/converter.log  # Follow app logs
sudo journalctl -u videoconverter -n 50 # Last 50 lines

# Configuration
sudo nano /etc/videoconverter/config.yml # Edit config
sudo systemctl reload videoconverter     # Reload config

# Troubleshooting
sudo systemctl status videoconverter     # Check status
sudo journalctl -u videoconverter -p err # View errors
sudo ps aux | grep videoconverter        # Check processes
```

### Directory Structure

```
/etc/videoconverter/          Configuration files
/var/lib/videoconverter/      Service state and lockfile
/var/log/videoconverter/      Application logs
/var/run/videoconverter/      Runtime files
/usr/local/bin/videoconverter Python script
/etc/systemd/system/videoconverter.service  Systemd unit
```

---

**Last Updated**: December 26, 2024  
**Version**: 1.0.0  
**Compatibility**: Ubuntu 24.04 LTS and derivatives
