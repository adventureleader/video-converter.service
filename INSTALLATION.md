# Video Converter Service - Installation Guide

Complete step-by-step instructions for installing the video-converter service on Ubuntu 24.04 and compatible systems.

## Table of Contents
1. [System Requirements](#system-requirements)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Installation Methods](#installation-methods)
4. [Post-Installation Configuration](#post-installation-configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements
- **OS:** Ubuntu 24.04 LTS or compatible derivative
- **CPU:** 2+ cores (4+ recommended for concurrent conversions)
- **RAM:** 4GB minimum (8GB+ recommended)
- **Disk Space:** 50GB+ for video storage and conversions
- **Python:** 3.10+ (included with Ubuntu 24.04)

### Optional GPU Support
- **NVIDIA:** NVIDIA GPU with NVENC support + nvidia-driver-open
- **AMD:** AMD GPU with VA-API support + mesa-va-drivers
- **Intel:** Intel GPU with QSV support + intel-media-va-driver-non-free

### Required Packages
The installation script will automatically install:
- `ffmpeg` - Video encoding/decoding
- `python3-venv` - Python virtual environments
- `python3-pip` - Python package manager
- `python3-watchdog` - File system monitoring
- `python3-yaml` - YAML configuration parsing

## Pre-Installation Checklist

Before installing, ensure:

```bash
# Check Ubuntu version
lsb_release -a

# Verify sudo access
sudo whoami

# Check available disk space
df -h /

# Check system resources
free -h
nproc
```

## Installation Methods

### Method 1: Automated Installation (Recommended)

The installation script handles all setup automatically.

#### Step 1: Download the Installation Script

```bash
# Clone the repository
git clone https://github.com/kb3kvq/video-converter.git
cd video-converter

# Or download directly
wget https://raw.githubusercontent.com/kb3kvq/video-converter/master/install_videoconverter.sh
chmod +x install_videoconverter.sh
```

#### Step 2: Run the Installation Script

```bash
# Basic installation (uses default user/group: videoconverter)
sudo ./install_videoconverter.sh

# Custom user and group
sudo ./install_videoconverter.sh --user myuser --group mygroup

# Show help
./install_videoconverter.sh --help
```

#### Step 3: Wait for Completion

The script will:
1. Update package lists
2. Install required packages
3. Create system user and group
4. Set up directory structure
5. Create configuration files
6. Install the Python service
7. Configure systemd integration
8. Start the service

Expected output:
```
✓ Running as root
✓ Ubuntu/Ubuntu derivative detected: Ubuntu 24.04 LTS
✓ Package lists updated
✓ Installed: ffmpeg
✓ Installed: python3-venv
...
✓ Service started
✓ Service is running
```

### Method 2: Manual Installation

If you prefer manual installation or the script fails:

#### Step 1: Install Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
    ffmpeg \
    python3-venv \
    python3-pip \
    python3-watchdog \
    python3-yaml
```

#### Step 2: Create User and Group

```bash
sudo groupadd --system videoconverter
sudo useradd \
    --system \
    --group videoconverter \
    --home-dir /var/lib/videoconverter \
    --shell /usr/sbin/nologin \
    --comment "Video Converter Service" \
    videoconverter
```

#### Step 3: Create Directory Structure

```bash
sudo mkdir -p /etc/videoconverter
sudo mkdir -p /var/log/videoconverter
sudo mkdir -p /var/lib/videoconverter
sudo mkdir -p /var/run/videoconverter

# Set permissions
sudo chmod 755 /etc/videoconverter
sudo chmod 750 /var/log/videoconverter
sudo chmod 750 /var/lib/videoconverter
sudo chmod 750 /var/run/videoconverter

# Set ownership
sudo chown videoconverter:videoconverter /var/log/videoconverter
sudo chown videoconverter:videoconverter /var/lib/videoconverter
sudo chown videoconverter:videoconverter /var/run/videoconverter
```

#### Step 4: Copy Configuration Files

```bash
# Copy the main Python script
sudo cp videoconverter /usr/local/bin/videoconverter
sudo chmod 755 /usr/local/bin/videoconverter

# Copy configuration template
sudo cp config.yml /etc/videoconverter/config.yml
sudo chmod 644 /etc/videoconverter/config.yml
```

#### Step 5: Create Environment File

```bash
sudo tee /etc/videoconverter/videoconverter.env > /dev/null << EOF
CONFIG_PATH=/etc/videoconverter/config.yml
LOG_PATH=/var/log/videoconverter
LOCK_PATH=/var/run/videoconverter/videoconverter.lock
EOF

sudo chmod 644 /etc/videoconverter/videoconverter.env
```

#### Step 6: Create Systemd Service File

```bash
sudo tee /etc/systemd/system/video-converter.service > /dev/null << EOF
[Unit]
Description=Video Converter Service - GPU-accelerated video conversion
Documentation=https://github.com/kb3kvq/video-converter
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=videoconverter
Group=videoconverter
EnvironmentFile=/etc/videoconverter/videoconverter.env
ExecStart=/usr/local/bin/videoconverter
Restart=on-failure
RestartSec=5s

StandardOutput=journal
StandardError=journal
SyslogIdentifier=videoconverter

PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/log/videoconverter /var/run/videoconverter /var/lib/videoconverter

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 644 /etc/systemd/system/video-converter.service
```

#### Step 7: Enable and Start the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable video-converter
sudo systemctl start video-converter
```

## Post-Installation Configuration

### Step 1: Edit Configuration File

```bash
sudo nano /etc/videoconverter/config.yml
```

Key configuration options:

```yaml
service:
  log_level: INFO              # DEBUG, INFO, WARNING, ERROR
  max_workers: 2               # Concurrent conversions
  conversion_timeout: 3600     # Timeout in seconds

directories:
  watch_paths:
    - /path/to/videos/incoming
  file_patterns:
    - "*.mkv"
    - "*.mp4"
  output_dir: ../converted

file_handling:
  delete_original: true        # Delete source after conversion
  preserve_permissions: true

error_handling:
  max_retries: 3
  retry_delay_seconds: 60
```

### Step 2: Create Watch Directories

```bash
# Create directories for video input
sudo mkdir -p /media/movies
sudo mkdir -p /media/tv-shows

# Set permissions (adjust as needed)
sudo chown videoconverter:videoconverter /media/movies
sudo chown videoconverter:videoconverter /media/tv-shows
sudo chmod 750 /media/movies
sudo chmod 750 /media/tv-shows
```

### Step 3: Update Configuration with Paths

```bash
sudo nano /etc/videoconverter/config.yml
```

Update the `watch_paths` section:

```yaml
directories:
  watch_paths:
    - path: /media/movies
      recursive: true
      enabled: true
    - path: /media/tv-shows
      recursive: true
      enabled: true
```

### Step 4: Restart the Service

```bash
sudo systemctl restart video-converter
```

## Verification

### Check Service Status

```bash
# Service status
sudo systemctl status video-converter

# Service is running
sudo systemctl is-active video-converter

# Service is enabled
sudo systemctl is-enabled video-converter
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u video-converter -f

# Last 50 lines
sudo journalctl -u video-converter -n 50

# Application logs
ls -la /var/log/videoconverter/
tail -f /var/log/videoconverter/videoconverter-*.log
```

### Test Conversion

```bash
# Copy a test video file
cp /path/to/test.mkv /media/movies/

# Monitor logs
sudo tail -f /var/log/videoconverter/videoconverter-*.log

# Check for converted file
ls -la /media/movies/converted/
```

## Troubleshooting

### Service Won't Start

```bash
# Check service status
sudo systemctl status video-converter

# View detailed logs
sudo journalctl -u video-converter -n 100

# Check configuration syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/videoconverter/config.yml'))"

# Restart service
sudo systemctl restart video-converter
```

### Permission Denied Errors

```bash
# Check directory ownership
ls -la /var/log/videoconverter/
ls -la /var/lib/videoconverter/

# Fix ownership
sudo chown -R videoconverter:videoconverter /var/log/videoconverter
sudo chown -R videoconverter:videoconverter /var/lib/videoconverter
```

### FFmpeg Not Found

```bash
# Verify ffmpeg installation
which ffmpeg
ffmpeg -version

# Reinstall if needed
sudo apt-get install --reinstall ffmpeg
```

### Configuration File Issues

```bash
# Validate YAML syntax
python3 -m yaml /etc/videoconverter/config.yml

# Check file permissions
ls -la /etc/videoconverter/config.yml

# Should be readable by all
sudo chmod 644 /etc/videoconverter/config.yml
```

### Conversions Not Starting

```bash
# Check watch paths exist
ls -la /media/movies/

# Verify service can read files
sudo -u videoconverter ls -la /media/movies/

# Check for lockfile issues
ls -la /var/run/videoconverter/

# Remove stale lockfile if needed
sudo rm -f /var/run/videoconverter/videoconverter.lock
sudo systemctl restart video-converter
```

## Uninstallation

To remove the service:

```bash
# Using the uninstall script
sudo ./uninstall_videoconverter.sh

# Or manually
sudo systemctl stop video-converter
sudo systemctl disable video-converter
sudo rm /etc/systemd/system/video-converter.service
sudo rm /usr/local/bin/videoconverter
sudo rm -rf /etc/videoconverter
sudo rm -rf /var/log/videoconverter
sudo rm -rf /var/run/videoconverter
sudo rm -rf /var/lib/videoconverter
sudo userdel -r videoconverter
sudo systemctl daemon-reload
```

## Support and Documentation

- **GitHub:** https://github.com/kb3kvq/video-converter
- **Issues:** https://github.com/kb3kvq/video-converter/issues
- **Documentation:** See README.md and ARCHITECTURE.md

## Next Steps

1. Configure watch directories in `/etc/videoconverter/config.yml`
2. Copy video files to watch directories
3. Monitor logs: `sudo journalctl -u video-converter -f`
4. Check converted files in output directory
5. Adjust settings as needed for your environment
