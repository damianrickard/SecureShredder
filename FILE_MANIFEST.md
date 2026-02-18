# SecureShredder - File Manifest

Complete listing of all project files and their purposes.

## Project Structure

```
/Users/damianrickard/coding/SecureShredder/
│
├── README.md                          # Main documentation
├── SETUP_GUIDE.md                     # Detailed setup instructions
├── QUICKSTART.md                      # Quick start guide
├── FILE_MANIFEST.md                   # This file
│
└── SecureShredder/                    # Main project directory
    │
    ├── SecureShredder/                # Main app source
    │   │
    │   ├── SecureShredderApp.swift    # App entry point (SwiftUI @main)
    │   ├── Info.plist                 # App configuration & URL scheme
    │   ├── SecureShredder.entitlements # Sandbox & file access permissions
    │   │
    │   ├── Models/                    # Data models
    │   │   ├── ShredConfiguration.swift  # Configuration (passes, chunk size, etc.)
    │   │   ├── ShredOperation.swift      # Operation state & progress tracking
    │   │   ├── FileItem.swift            # File/folder representation
    │   │   └── ShredResult.swift         # Operation results & statistics
    │   │
    │   ├── Core/                      # Core shredding logic ⭐
    │   │   ├── DoDPattern.swift          # DoD 5220.22-M pattern generator
    │   │   ├── FileOverwriter.swift      # POSIX I/O file overwriting
    │   │   ├── FileDiscovery.swift       # Recursive file enumeration
    │   │   ├── SecureDeletion.swift      # Secure file deletion
    │   │   └── ShredEngine.swift         # Main orchestration engine
    │   │
    │   ├── ViewModels/                # MVVM ViewModels
    │   │   └── MainViewModel.swift       # Main app state & logic
    │   │
    │   ├── Views/                     # SwiftUI views
    │   │   ├── MainView.swift            # Main app interface
    │   │   ├── DropZoneView.swift        # Drag-drop file zone
    │   │   ├── ConfirmationView.swift    # Deletion confirmation dialog
    │   │   ├── ProgressView.swift        # Progress tracking view
    │   │   └── Components/
    │   │       └── WarningBannerView.swift # APFS/SSD warning banner
    │   │
    │   └── Utilities/                 # Utility classes (currently empty)
    │
    ├── ShredderQuickAction/           # Finder integration extension
    │   ├── ActionRequestHandler.swift    # Extension handler (URL scheme launcher)
    │   └── Info.plist                    # Extension configuration
    │
    └── SecureShredderTests/           # Unit tests
        ├── DoDPatternTests.swift         # Tests for pattern generation
        ├── ShredConfigurationTests.swift # Tests for configuration
        └── FileItemTests.swift           # Tests for file items
```

## File Count Summary

- **Swift source files**: 18
- **Configuration files**: 3 (2 Info.plist, 1 entitlements)
- **Documentation files**: 4 (README, SETUP_GUIDE, QUICKSTART, this file)
- **Test files**: 3
- **Total**: 28 files

## Critical Files (Must Have)

These files are essential for the app to function:

### Core Logic (5 files)
1. `Core/DoDPattern.swift` - Pattern generation
2. `Core/FileOverwriter.swift` - Actual overwriting with POSIX I/O
3. `Core/FileDiscovery.swift` - Find files in folders
4. `Core/SecureDeletion.swift` - Delete files
5. `Core/ShredEngine.swift` - Tie everything together

### Models (4 files)
6. `Models/ShredConfiguration.swift` - Settings
7. `Models/ShredOperation.swift` - Progress tracking
8. `Models/FileItem.swift` - File representation
9. `Models/ShredResult.swift` - Results

### Views (5 files)
10. `Views/MainView.swift` - Main UI
11. `Views/DropZoneView.swift` - File dropping
12. `Views/ConfirmationView.swift` - Confirm dialog
13. `Views/ProgressView.swift` - Progress display
14. `Views/Components/WarningBannerView.swift` - Warning

### ViewModels (1 file)
15. `ViewModels/MainViewModel.swift` - State management

### App Entry (1 file)
16. `SecureShredderApp.swift` - Launch point

### Configuration (2 files)
17. `Info.plist` - App config
18. `SecureShredder.entitlements` - Permissions

**Total Critical Files: 18**

## Optional Files

### Finder Integration (2 files)
- `ShredderQuickAction/ActionRequestHandler.swift`
- `ShredderQuickAction/Info.plist`

*App works without these, but no right-click in Finder*

### Unit Tests (3 files)
- All files in `SecureShredderTests/`

*Optional but recommended for quality assurance*

## File Sizes (Approximate)

```
SecureShredderApp.swift         ~0.5 KB
DoDPattern.swift                ~5 KB
FileOverwriter.swift            ~7 KB
FileDiscovery.swift             ~3 KB
SecureDeletion.swift            ~2 KB
ShredEngine.swift               ~6 KB
ShredConfiguration.swift        ~1 KB
ShredOperation.swift            ~3 KB
FileItem.swift                  ~2 KB
ShredResult.swift               ~2 KB
MainViewModel.swift             ~5 KB
MainView.swift                  ~3 KB
DropZoneView.swift              ~4 KB
ConfirmationView.swift          ~3 KB
ProgressView.swift              ~4 KB
WarningBannerView.swift         ~3 KB
ActionRequestHandler.swift      ~3 KB

Total Swift code: ~55 KB
Documentation: ~25 KB
```

## Dependencies

### External Frameworks
- Foundation (built-in)
- SwiftUI (built-in)
- AppKit (built-in)
- Combine (built-in)
- Security (built-in)

**No third-party dependencies!** 🎉

### System Requirements
- macOS 13.0+ (Ventura)
- Xcode 15.0+
- Swift 5.9+

## Build Targets

### 1. SecureShredder (Main App)
**Includes:**
- SecureShredderApp.swift
- All Models/
- All Core/
- All ViewModels/
- All Views/
- Info.plist
- SecureShredder.entitlements

### 2. ShredderQuickAction (Extension)
**Includes:**
- ActionRequestHandler.swift
- Info.plist

### 3. SecureShredderTests (Tests)
**Includes:**
- All test files

## Key Technologies Used

| File | Technology |
|------|-----------|
| DoDPattern.swift | Security framework (SecRandomCopyBytes) |
| FileOverwriter.swift | POSIX I/O (open, write, fcntl) |
| ShredEngine.swift | Swift Concurrency (async/await) |
| MainViewModel.swift | Combine framework |
| All Views | SwiftUI |
| ActionRequestHandler.swift | NSExtension API |

## Lines of Code (Approximate)

```
Core/               ~400 LOC
Models/             ~200 LOC
ViewModels/         ~150 LOC
Views/              ~350 LOC
Extension/          ~70 LOC
Tests/              ~250 LOC
─────────────────────────────
Total:              ~1,420 LOC
```

## Git Ignore Recommendations

Add to `.gitignore`:
```
.DS_Store
*.xcuserstate
*.xcuserdatad
DerivedData/
build/
*.swp
*~
.swiftpm
```

## Next Steps After Setup

1. ✅ Verify all files are present
2. ✅ Add files to correct Xcode targets
3. ✅ Configure entitlements
4. ✅ Build project
5. ✅ Run tests
6. ✅ Test functionality
7. ⬜ Add app icon (optional)
8. ⬜ Localize strings (optional)
9. ⬜ Create installer (optional)

---

**All files are ready to use!** Follow [SETUP_GUIDE.md](SETUP_GUIDE.md) to build the project.
