# SecureShredder - macOS Secure File Deletion App

A native macOS application using Swift/SwiftUI that securely overwrites and deletes files/folders using the DoD 5220.22-M standard.

## ⚠️ Important Security Disclosure

This app prominently warns users that traditional file overwriting is largely ineffective on APFS encrypted volumes and modern SSDs due to copy-on-write and wear leveling. This provides "best-effort" secure deletion primarily effective for non-encrypted external drives.

## Features

- ✅ Drag-and-drop interface for files and folders
- ✅ DoD 5220.22-M compliant overwriting (zeros, ones, random data)
- ✅ User-selectable overwrite passes (1, 3, 7, 35)
- ✅ Real-time progress tracking with pass and file information
- ✅ Finder Quick Action integration (right-click to shred)
- ✅ Sandboxed with user-selected file access only
- ✅ No logging or data collection
- ✅ macOS 13.0+ (Ventura and later)

## Technology Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Combine
- **Minimum macOS**: 13.0 (Ventura)
- **Target**: Universal binary (Apple Silicon + Intel)

## Project Structure

```
SecureShredder/
├── SecureShredder/                    # Main App Target
│   ├── SecureShredderApp.swift        # App entry point
│   ├── Models/                        # Data models
│   │   ├── ShredConfiguration.swift
│   │   ├── ShredOperation.swift
│   │   ├── FileItem.swift
│   │   └── ShredResult.swift
│   ├── Core/                          # Core logic
│   │   ├── DoDPattern.swift           # DoD 5220.22-M pattern generator
│   │   ├── FileOverwriter.swift       # POSIX I/O overwriting
│   │   ├── FileDiscovery.swift        # Recursive file enumeration
│   │   ├── SecureDeletion.swift       # Secure file deletion
│   │   └── ShredEngine.swift          # Main orchestrator
│   ├── ViewModels/                    # View models
│   │   └── MainViewModel.swift
│   ├── Views/                         # SwiftUI views
│   │   ├── MainView.swift
│   │   ├── DropZoneView.swift
│   │   ├── ConfirmationView.swift
│   │   ├── ProgressView.swift
│   │   └── Components/
│   │       └── WarningBannerView.swift
│   ├── Info.plist
│   └── SecureShredder.entitlements
│
└── ShredderQuickAction/               # Finder Quick Action Extension
    ├── ActionRequestHandler.swift
    └── Info.plist
```

## Setup Instructions

### Option 1: Create Project in Xcode (Recommended)

1. **Open Xcode** (Xcode 15+ recommended)

2. **Create New Project**:
   - File → New → Project
   - Choose: **macOS → App**
   - Product Name: `SecureShredder`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Save to: `/Users/damianrickard/coding/SecureShredder`

3. **Delete Default Files**:
   - Delete the automatically created `ContentView.swift`
   - Delete the automatically created `SecureShredderApp.swift`

4. **Add Source Files**:
   - Drag the `SecureShredder/SecureShredder` folder into the Xcode project navigator
   - Ensure "Copy items if needed" is **unchecked**
   - Select "Create groups"
   - Add to target: SecureShredder

5. **Add Action Extension**:
   - File → New → Target
   - Choose: **macOS → Action Extension**
   - Product Name: `ShredderQuickAction`
   - Language: Swift
   - Delete the default `ActionViewController.swift`
   - Add `ShredderQuickAction/ActionRequestHandler.swift`
   - Replace `Info.plist` with the provided one

6. **Configure Entitlements**:
   - Select project → Target "SecureShredder" → Signing & Capabilities
   - Click **+ Capability** → **App Sandbox**
   - Under File Access → User Selected Files: **Read/Write**
   - Or use the provided `SecureShredder.entitlements` file

7. **Configure Info.plist**:
   - Replace the auto-generated Info.plist with the provided one
   - Ensure URL scheme `secureshredder://` is registered

8. **Build and Run**:
   - Select "SecureShredder" scheme
   - Product → Run (⌘R)

### Option 2: Import Existing Files

If you prefer to manually link files:

```bash
cd /Users/damianrickard/coding/SecureShredder
open -a Xcode SecureShredder.xcodeproj
```

Then follow steps 4-8 from Option 1.

## Technical Details

### DoD 5220.22-M Standard

Each pass consists of 3 patterns:
1. **Pass 1**: Write 0x00 (all zeros)
2. **Pass 2**: Write 0xFF (all ones)
3. **Pass 3**: Write cryptographically secure random data using `SecRandomCopyBytes()`

With 7 passes (default), the app writes **21 patterns** total.

### Critical Implementation Details

**F_FULLFSYNC for macOS**: Regular `fsync()` only writes to disk cache on macOS. The app uses `fcntl(fd, F_FULLFSYNC)` to ensure data reaches physical disk.

**POSIX Direct I/O**: Uses `open()` with `O_RDWR | O_SYNC` flags for direct I/O without system caching.

**Chunk-based Writing**: Writes in 1MB chunks to manage memory efficiently.

**Progress Calculation**:
```swift
let fileWeight = 1.0 / totalFiles
let passWeight = fileWeight / totalPasses
let progress = (fileIndex * fileWeight) + (currentPass * passWeight) + chunkProgress
```

**Memory Security**: All pattern buffers are zeroed using `memset_s()` after use.

## Usage

### Main App

1. **Launch** SecureShredder
2. **Drag and drop** files/folders onto the drop zone, or click "Choose Files"
3. **Select passes**: Choose 1, 3, 7, or 35 passes (default: 7)
4. **Click "Shred Files"**
5. **Confirm** the operation
6. **Monitor progress** - shows current file, pass number, and percentage
7. **Done** - files are securely overwritten and deleted

### Finder Quick Action

1. **Select files** in Finder
2. **Right-click** → "Quick Actions" → "Secure Shred"
3. SecureShredder launches with files pre-selected
4. **Confirm and proceed** as above

## Security Considerations

### What This App Does

✅ Overwrites file data multiple times with DoD patterns
✅ Uses cryptographically secure random data
✅ Forces physical disk writes with F_FULLFSYNC
✅ Bypasses Trash (direct deletion)
✅ Effective on non-encrypted external drives
✅ Defeats casual recovery tools

### Limitations (Clearly Disclosed to Users)

⚠️ **APFS**: Uses copy-on-write, preventing true physical overwriting
⚠️ **SSDs**: Wear leveling redirects writes to different sectors
⚠️ **FileVault**: On encrypted volumes, original data may persist

**Maximum Security on FileVault**:
Delete file → Change FileVault password → This re-encrypts the volume with a new key

### What Makes This Secure

1. **No Logging**: Zero persistent logs of file contents or operations
2. **Sandboxing**: App Sandbox with user-selected file access only
3. **Memory Security**: Buffers are securely zeroed after use
4. **Verification**: Optional final pass verification
5. **Error Handling**: Per-file error handling (continues on failure)

## Building

### Requirements

- macOS 13.0+ (Ventura)
- Xcode 15.0+
- Swift 5.9+

### Build Commands

```bash
# Build from command line
xcodebuild -project SecureShredder.xcodeproj -scheme SecureShredder -configuration Release build

# Create archive
xcodebuild -project SecureShredder.xcodeproj -scheme SecureShredder -configuration Release archive -archivePath ./build/SecureShredder.xcarchive

# Export app
xcodebuild -exportArchive -archivePath ./build/SecureShredder.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist
```

## Testing

### Manual Testing Checklist

- [ ] Drag-drop single file
- [ ] Drag-drop multiple files
- [ ] Drag-drop folder with nested structure
- [ ] File picker selection
- [ ] Right-click single file in Finder → SecureShredder
- [ ] Right-click folder in Finder
- [ ] Confirmation dialog shows correct info
- [ ] Progress bar updates smoothly
- [ ] Cancel during operation
- [ ] Test with small files (<1MB)
- [ ] Test with large files (>1GB)
- [ ] Test 1, 3, 7, and 35 pass operations
- [ ] Locked file handling
- [ ] Permission denied handling
- [ ] Files deleted and NOT in Trash
- [ ] Warning banner displays
- [ ] Test on APFS internal drive
- [ ] Test on external drive

### Unit Tests

Unit tests can be added for:
- `DoDPattern`: Pattern generation and cycling
- `FileOverwriter`: Overwrite operations and progress
- `FileDiscovery`: Recursive enumeration
- `ShredEngine`: Complete workflow and cancellation

## Known Issues

1. **Quick Action may require restart**: After installing, you may need to log out/in for the Finder Quick Action to appear
2. **Large files**: Files >10GB may take significant time (expected behavior)
3. **APFS limitations**: Warning banner clearly discloses this limitation

## License

This project is for educational and personal use. Use at your own risk.

## Disclaimer

This software is provided "as-is" without any guarantees. The effectiveness of secure deletion depends on:
- Filesystem type (HFS+, APFS, FAT32, etc.)
- Drive type (HDD vs SSD)
- Encryption status (FileVault, etc.)
- Firmware and hardware behavior

Always test with non-critical data first.

---

## Development Notes

### Why These Choices?

- **Swift/SwiftUI**: Native performance, modern async/await
- **MVVM**: Clear separation, testability
- **POSIX I/O**: Need O_SYNC and F_FULLFSYNC for guaranteed writes
- **Quick Action**: Apple's recommended extension for Finder integration
- **URL Scheme**: Standard IPC between extension and main app

### Future Enhancements

- [ ] Gutmann method (35-pass standard)
- [ ] Custom pass patterns
- [ ] Scheduled shredding
- [ ] Secure empty trash
- [ ] Command-line interface
- [ ] Unit test suite
- [ ] Performance benchmarks
- [ ] Localization

---

**Version**: 1.0
**macOS**: 13.0+ (Ventura, Sonoma, Sequoia)
**Last Updated**: January 2026
