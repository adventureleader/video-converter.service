# Video Converter Service - Uninstall Guide

This guide provides step-by-step instructions to completely remove the video-converter service from your Ubuntu system.

## Prerequisites
- Root or sudo access
- The service must be stopped before uninstallation

## Uninstall Steps

### 1. Stop the Service
```bash
sudo systemctl stop video-converter
```

### 2. Disable the Service
```bash
sudo systemctl disable video-converter
```

### 3. Remove the Systemd Service File
```bash
sudo rm /etc/systemd/system/video-converter.service
```

### 4. Reload Systemd Daemon
```bash
sudo systemctl daemon-reload
```

### 5. Remove the Service Binary
```bash
sudo rm /usr/local/bin/videoconverter
```

### 6. Remove Configuration Files
```bash
sudo rm -rf /etc/videoconverter
```

### 7. Remove Log Files
```bash
sudo rm -rf /var/log/videoconverter
```

### 8. Remove Runtime Files (Lockfile, PID)
```bash
sudo rm -rf /var/run/videoconverter
```

### 9. Remove Service User and Group (Optional)
If you created a dedicated user for the service:
```bash
sudo userdel -r videoconverter
```

### 10. Remove Queue Directory (Optional)
If you created a queue directory:
```bash
sudo rm -rf /var/lib/videoconverter
```

## Verification

Verify the service has been completely removed:

```bash
# Check if service file exists
ls /etc/systemd/system/video-converter.service

# Check if binary exists
which videoconverter

# Check systemd status
systemctl status video-converter

# List remaining videoconverter files
find / -name "*videoconverter*" 2>/dev/null
```

All commands should return "not found" or no results.

## Complete Uninstall Script

If you prefer to uninstall everything at once, run this script:

```bash
#!/bin/bash
set -e

echo "Stopping video-converter service..."
sudo systemctl stop video-converter || true

echo "Disabling video-converter service..."
sudo systemctl disable video-converter || true

echo "Removing systemd service file..."
sudo rm -f /etc/systemd/system/video-converter.service

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Removing service binary..."
sudo rm -f /usr/local/bin/videoconverter

echo "Removing configuration..."
sudo rm -rf /etc/videoconverter

echo "Removing logs..."
sudo rm -rf /var/log/videoconverter

echo "Removing runtime files..."
sudo rm -rf /var/run/videoconverter

echo "Removing queue directory..."
sudo rm -rf /var/lib/videoconverter

echo "Removing service user (optional)..."
sudo userdel -r videoconverter 2>/dev/null || true

echo "Uninstallation complete!"
```

Save this as `uninstall.sh`, make it executable, and run:
```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Cleanup Converted Files

If you want to remove converted video files:

```bash
# Remove all converted files (be careful!)
sudo rm -rf /path/to/converted/videos

# Or selectively remove by pattern
sudo find /path/to/videos -name "*.mp4" -delete
```

## Restore Original Files

If you enabled `delete_original: true` in the configuration, original files were deleted after conversion. If you have backups, restore them now:

```bash
# Example: restore from backup
sudo cp -r /backup/original/videos /path/to/videos
```

## Troubleshooting

### Service Won't Stop
```bash
# Force kill the service
sudo pkill -9 videoconverter
sudo pkill -9 ffmpeg
```

### Permission Denied Errors
Ensure you're using `sudo` for all commands that modify system files.

### Files Still Exist
Use `find` to locate remaining files:
```bash
sudo find / -name "*videoconverter*" 2>/dev/null
```

## Notes

- The uninstall process does not remove converted video files by default
- Configuration backups are not automatically created; save them if needed
- If the service was running conversions, they will be interrupted
- The lockfile at `/var/run/videoconverter/videoconverter.lock` will be removed when the service stops
