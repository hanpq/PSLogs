# File Flush Enhancement for Wait-Logging

## Problem Statement

Currently, `Wait-Logging` only waits for the message queue to be emptied, but doesn't guarantee that the OS has actually flushed file data to disk. This can lead to data loss scenarios where:

1. `Wait-Logging` completes successfully (queue is empty)
2. PowerShell session terminates immediately after
3. OS hasn't completed writing buffered data to disk
4. Log data is lost

This is particularly problematic in scenarios like:
- Scheduled tasks that terminate immediately after logging
- Scripts that exit right after critical error logging
- Automated processes where log integrity is crucial

## Current Behavior

```powershell
Wait-Logging  # Only waits for queue to be empty
# PowerShell exits - potential data loss if OS buffers aren't flushed
```

## Requirements

### Functional Requirements
- **No performance impact on normal logging**: File flushing should NOT occur during regular logging operations
- **Explicit flushing only**: File buffers should only be flushed when `Wait-Logging` is explicitly called
- **Order of operations**: Queue must be drained completely before any file flushing occurs
- **Cross-platform compatibility**: Solution should work on Windows, Linux, and macOS

### Technical Requirements
- Minimal changes to existing logging architecture
- Thread-safe implementation for concurrent access
- Graceful handling of disposed/closed file handles
- Support for multiple File targets with different paths

## Proposed Solution

### Approach: File Handle Registry

Implement a module-scoped registry that tracks active file handles and provides flush capabilities on demand.

#### Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Write-Log     │───▶│ Message Queue    │───▶│ Consumer        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Wait-Logging  │───▶│ File Handle      │◀───│ File Target     │
│                 │    │ Registry         │    │ Logger          │
│ 1. Drain Queue  │    │                  │    └─────────────────┘
│ 2. Flush Files  │    │ Path → Handle    │
└─────────────────┘    └──────────────────┘
```

#### Implementation Details

##### 1. Module-Level Registry
```powershell
# In Set-LoggingVariables or module initialization
$Script:ActiveFileHandles = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
```

##### 2. File Target Modifications
Modify `source/include/File.ps1` to:
- Use `FileStream` instead of `Out-File` for better control
- Register file handles in the global registry
- Implement proper disposal and cleanup

```powershell
# Pseudo-code for File target Logger block
$Logger = {
    param($Log, $Configuration)
    
    # Get or create FileStream for this path
    $filePath = Format-Pattern -Pattern $Configuration.Path -Source $Log
    
    if (!$Script:ActiveFileHandles.ContainsKey($filePath)) {
        $stream = [System.IO.FileStream]::new($filePath, 'Append', 'Write', 'Read')
        $writer = [System.IO.StreamWriter]::new($stream)
        $Script:ActiveFileHandles[$filePath] = @{
            Stream = $stream
            Writer = $writer
        }
    }
    
    $handle = $Script:ActiveFileHandles[$filePath]
    $handle.Writer.WriteLine($Text)
    # NO flush here - only on explicit Wait-Logging call
}
```

##### 3. Wait-Logging Enhancement
```powershell
function Wait-Logging {
    # ... existing parameter validation ...
    
    # Step 1: Wait for queue to drain (existing logic)
    while ($Script:LoggingEventQueue.Count -gt 0) {
        Start-Sleep -Milliseconds 20
        # ... existing timeout logic ...
    }
    
    # Step 2: NEW - Flush all registered file handles
    foreach ($entry in $Script:ActiveFileHandles.GetEnumerator()) {
        $handle = $entry.Value
        try {
            if ($handle.Writer -and !$handle.Writer.BaseStream.Disposed) {
                $handle.Writer.Flush()
                $handle.Stream.Flush()
                if ($handle.Stream.GetType().GetMethod('FlushToDisk')) {
                    $handle.Stream.FlushToDisk()  # .NET Core cross-platform
                }
            }
        } catch {
            # Log flush errors but don't fail the wait operation
            Write-Warning "Failed to flush file handle: $_"
        }
    }
}
```

##### 4. Cleanup and Disposal
Handle cleanup in:
- `Remove-LoggingTarget`: Remove handles for specific targets
- `Stop-LoggingManager`: Dispose all handles during shutdown
- Target disposal: When File targets are removed/replaced

```powershell
# In Remove-LoggingTarget for File targets
if ($targetType -eq 'File' -and $Script:ActiveFileHandles.ContainsKey($targetPath)) {
    $handle = $Script:ActiveFileHandles[$targetPath]
    $handle.Writer.Dispose()
    $handle.Stream.Dispose()
    $Script:ActiveFileHandles.TryRemove($targetPath, [ref]$null)
}
```

## Alternative Approaches Considered

### Message-Based Flush Command
- **Pros**: Uses existing queue infrastructure
- **Cons**: More complex, requires consumer runspace modifications, harder to synchronize

### Target-Level State Tracking
- **Pros**: Self-contained per target
- **Cons**: More complex enumeration, requires changes to all File target instances

### Callback-Based System
- **Pros**: Extensible to other target types
- **Cons**: Added complexity, function pointer management

## Implementation Plan

### Phase 1: Core Infrastructure
1. Add `ActiveFileHandles` registry to module initialization
2. Create helper functions for handle management
3. Update `Wait-Logging` with flush logic

### Phase 2: File Target Updates
1. Modify File target to use FileStream
2. Implement handle registration/cleanup
3. Add error handling and disposal logic

### Phase 3: Integration & Testing
1. Update existing tests for new behavior
2. Add specific flush testing scenarios
3. Test cross-platform compatibility
4. Performance testing to ensure no regression

### Phase 4: Documentation
1. Update `Wait-Logging` documentation
2. Add developer notes about file handle lifecycle
3. Update examples and best practices

## Testing Strategy

### Unit Tests
- Handle registration and cleanup
- Flush operation success/failure scenarios
- Concurrent access to file handles
- Disposal edge cases

### Integration Tests
- End-to-end logging with explicit flush verification
- Multiple File targets with same/different paths
- Performance impact measurement
- Cross-platform compatibility

### Manual Testing Scenarios
- Script termination after `Wait-Logging`
- Large log files and buffer management
- Network drives and slow I/O scenarios
- Memory pressure and handle limits

## Risks and Mitigations

### Risk: Memory Leaks from Unclosed Handles
**Mitigation**: Implement proper disposal in all cleanup paths, add finalizers if needed

### Risk: Performance Impact on High-Volume Logging
**Mitigation**: Only flush on explicit `Wait-Logging` calls, use efficient concurrent collections

### Risk: Cross-Platform FileStream Differences
**Mitigation**: Feature detection for `FlushToDisk()`, fallback to standard `Flush()`

### Risk: Breaking Changes to File Target
**Mitigation**: Maintain backward compatibility, extensive testing of existing scenarios

## Success Criteria

1. **Functional**: `Wait-Logging` ensures all file data is committed to disk before returning
2. **Performance**: No measurable impact on normal logging throughput
3. **Reliability**: Proper cleanup prevents handle leaks and resource exhaustion
4. **Compatibility**: Works across all supported PowerShell versions and platforms
5. **Maintainability**: Clean, well-documented code that's easy to extend

## Future Enhancements

- Extend flush capability to other target types (network targets, databases)
- Add configuration option to control flush behavior per target
- Implement flush timeout and retry logic
- Add metrics/telemetry for flush operations
