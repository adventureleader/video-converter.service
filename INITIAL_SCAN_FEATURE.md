# Initial File Scan Feature

**Commit:** `e0d3028`  
**Date:** 2025-12-27

## Overview

The video-converter service now includes an **initial scan feature** that discovers and queues existing files in watch directories when the service starts. This ensures that files already present in the directories are processed, not just newly created or modified files.

## What Changed

### New Method: `_scan_existing_files()`

Added a new method to the [`VideoConverterService`](videoconverter:1039) class that:

1. **Scans watch directories** on service startup
2. **Matches files** against configured patterns (e.g., `*.mkv`)
3. **Checks file stability** to ensure files aren't being written
4. **Queues files** for conversion if they match criteria
5. **Tracks progress** with detailed logging

### Implementation Details

**Location:** [`videoconverter:1167-1210`](videoconverter:1167)

```python
def _scan_existing_files(self, event_handler: VideoFileEventHandler, watch_paths: List[str]) -> None:
    """
    Scan watch directories for existing files and queue them for conversion.
    """
```

**Features:**
- Respects `recursive` configuration setting
- Uses glob patterns for efficient file discovery
- Skips directories automatically
- Validates file patterns before queuing
- Checks file stability (5-second check) before processing
- Provides detailed logging of scan results

### Integration

The initial scan is triggered automatically in [`_start_monitoring()`](videoconverter:1126):

```python
# Perform initial scan of existing files
self._scan_existing_files(event_handler, watch_paths)
```

This happens **after** the watchdog observer starts, ensuring:
- Real-time monitoring is active
- Files discovered during scan are tracked
- No race conditions between scan and live monitoring

## Behavior

### On Service Startup

1. Service starts and initializes watchdog monitoring
2. Watchdog observer begins monitoring directories
3. Initial scan discovers existing files
4. Matching files are queued for conversion
5. Service logs scan results

### Example Log Output

```json
{"timestamp": "2025-12-27T16:05:39.451182Z", "level": "INFO", "message": "Performing initial scan of existing files..."}
{"timestamp": "2025-12-27T16:05:39.451415Z", "level": "INFO", "message": "Monitoring directory: /media/movies"}
{"timestamp": "2025-12-27T16:05:40.631045Z", "level": "INFO", "message": "Initial scan complete: 5 file(s) queued for conversion"}
```

## Configuration

The initial scan respects all configuration settings:

```yaml
directories:
  watch_paths:
    - path: /media/movies
      recursive: true
      enabled: true
  file_patterns:
    - "*.mkv"
    - "*.mp4"
```

- **recursive:** If `true`, scans subdirectories; if `false`, only top-level
- **file_patterns:** Only files matching these patterns are queued
- **enabled:** Only enabled paths are scanned

## File Stability Check

Before queuing a file, the service verifies it's not being written:

1. Records initial file size
2. Waits 5 seconds (configurable via `FILE_STABILITY_CHECK_DURATION`)
3. Checks file size again
4. If size unchanged, file is stable and queued
5. If size changed, file is skipped (still being written)

This prevents processing incomplete uploads or transfers.

## Benefits

✅ **Existing files are processed** - No need to manually trigger modifications  
✅ **Automatic discovery** - Files are found on service startup  
✅ **Safe processing** - File stability check prevents incomplete files  
✅ **Configurable** - Respects all existing configuration options  
✅ **Logged** - Detailed information about scan progress  
✅ **Non-blocking** - Scan happens after monitoring starts  

## Usage

No configuration changes needed. The feature works automatically:

```bash
# Restart the service
sudo systemctl restart video-converter

# Monitor logs to see initial scan
sudo tail -f /var/log/videoconverter/videoconverter-*.log
```

## Example Scenario

**Before:** Service starts, watches for new files only
```
Service starts → Waits for new files → No existing files processed
```

**After:** Service starts, scans existing files
```
Service starts → Scans existing files → Queues matching files → Processes them
```

## Technical Details

### File Discovery Algorithm

1. For each watch path:
   - Check if path exists
   - Get recursive setting
   - Use glob pattern: `**/*` (recursive) or `*` (non-recursive)
   - Iterate through results

2. For each file:
   - Skip if it's a directory
   - Check if filename matches patterns
   - Verify file stability
   - Queue if all checks pass

### Performance Considerations

- **Glob scanning:** Efficient for large directories
- **Stability check:** 5-second delay per file (configurable)
- **Pattern matching:** Uses Python's `pathlib.match()` (fast)
- **Non-blocking:** Scan completes before service enters main loop

### Error Handling

- Skips directories that don't exist
- Catches and logs exceptions per directory
- Continues scanning other directories if one fails
- Reports total files queued

## Testing

To test the initial scan feature:

```bash
# 1. Add test files to watch directory
cp /path/to/test.mkv /media/movies/

# 2. Restart service
sudo systemctl restart video-converter

# 3. Check logs for initial scan
sudo journalctl -u video-converter -n 20

# 4. Verify files are queued
tail -f /var/log/videoconverter/videoconverter-*.log
```

Expected output:
```
Performing initial scan of existing files...
Monitoring directory: /media/movies
Initial scan complete: 1 file(s) queued for conversion
```

## Future Enhancements

Possible improvements:
- Add configuration option to disable initial scan
- Add option to skip stability check for faster scanning
- Add option to limit number of files scanned
- Add progress reporting for large directories
- Add option to process files in specific order (by date, size, etc.)

## Backward Compatibility

✅ **Fully backward compatible** - No breaking changes
- Existing configurations work unchanged
- Feature is automatic and transparent
- No new required configuration options
- Existing behavior for new files unchanged

## Related Files

- [`videoconverter`](videoconverter) - Main service script
- [`INSTALLATION.md`](INSTALLATION.md) - Installation guide
- [`DEPLOYMENT_STATUS.md`](DEPLOYMENT_STATUS.md) - Deployment status
