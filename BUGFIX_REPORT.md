# Video Converter Service - Bug Fix Report

## Issue Summary
The video-converter service was running for several hours with no progress. FFmpeg was still running but failing silently on conversions.

## Root Cause Analysis

### Primary Issue: Attached Picture Stream Mapping
**Location:** [`videoconverter:759-813`](videoconverter:759)

The ffmpeg command was using `-map 0:v -map 0:a` which maps **all** video and audio streams from the input file. In the test case, the input MKV file contained:
- Stream #0:0: Video (h264, 1920x1080)
- Stream #0:1: Audio (ac3, Greek)
- Stream #0:2: Audio (ac3, English)
- Stream #0:3: Subtitle (subrip)
- Stream #0:4: **Attached Picture** (mjpeg, cover art)

The ffmpeg command attempted to encode the attached picture (stream #0:4) as HEVC video, which is not supported in MP4 containers. This caused the error:

```
[mp4 @ 0x5edac8185300] Could not find tag for codec hevc in stream #1, codec not currently supported in container
[out#0/mp4 @ 0x5edac8182bc0] Could not write header (incorrect codec parameters ?): Invalid argument
Error while filtering: Invalid argument
```

### Secondary Issue: Configuration Format Mismatch
**Location:** [`videoconverter:234-236`](videoconverter:234)

The code expected `watch_paths` to be a simple list of strings:
```yaml
watch_paths:
  - /path/to/videos
```

However, the config.yml file defined it as a list of objects:
```yaml
watch_paths:
  - path: /var/lib/videoconverter/queue
    recursive: true
    enabled: true
```

This mismatch would cause the service to fail parsing the configuration or ignore the watch paths entirely.

## Fixes Applied

### Fix 1: Selective Stream Mapping
**File:** [`videoconverter`](videoconverter:759)

Changed the ffmpeg command builder to explicitly map only the first video stream and all audio streams, excluding attached pictures:

```python
# Map only the first video stream and all audio streams (exclude attached pictures)
cmd.extend([
    "-map", "0:v:0",  # First video stream only
    "-map", "0:a"     # All audio streams
])
```

This ensures:
- Only the primary video stream is encoded
- All audio tracks are preserved
- Attached pictures (cover art) are excluded
- Subtitles are excluded (can be added back if needed)

### Fix 2: Flexible Configuration Parsing
**File:** [`videoconverter`](videoconverter:234)

Updated `get_watch_paths()` to handle both configuration formats:

```python
def get_watch_paths(self) -> List[str]:
    """Get list of directories to monitor."""
    watch_paths_config = self.config_data.get("directories", {}).get("watch_paths", [])
    
    # Handle both list of strings and list of dicts with 'path' key
    watch_paths = []
    for item in watch_paths_config:
        if isinstance(item, dict):
            # Check if enabled (default to True if not specified)
            if item.get("enabled", True):
                watch_paths.append(item.get("path"))
        elif isinstance(item, str):
            watch_paths.append(item)
    
    return [p for p in watch_paths if p]  # Filter out None values
```

This allows the service to work with:
- Simple string lists (backward compatible)
- Complex object lists with enable/disable flags
- Mixed formats

## Testing Recommendations

1. **Test with MKV files containing cover art:**
   - Verify conversions complete successfully
   - Check that output MP4 files are valid

2. **Test configuration parsing:**
   - Verify both simple and complex watch_paths formats work
   - Test with disabled paths to ensure they're skipped

3. **Monitor service logs:**
   - Check for any remaining ffmpeg errors
   - Verify conversion progress is logged

## Files Modified
- `videoconverter` - Main service script (2 changes)

## Deployment Notes
After applying these fixes:
1. Restart the video-converter service
2. Clear any stuck conversion tasks from the queue
3. Monitor the logs for successful conversions
4. Consider adding subtitle stream mapping if needed: `-map 0:s?` (optional subtitles)
