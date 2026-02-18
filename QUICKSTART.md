# SecureShredder - Quick Start

Get up and running in 5 minutes!

## TL;DR

1. Open Xcode
2. Create new macOS App project named "SecureShredder"
3. Delete default files
4. Drag in all source files from `SecureShredder/SecureShredder/`
5. Add Action Extension target named "ShredderQuickAction"
6. Add extension files
7. Enable App Sandbox + User Selected Files (Read/Write)
8. Build & Run!

## Detailed Steps

### 1. Create Project (2 minutes)

```
Xcode → File → New → Project
→ macOS → App
→ Name: "SecureShredder"
→ Interface: SwiftUI
→ Language: Swift
→ Save to: /Users/damianrickard/coding/SecureShredder
```

### 2. Add Source Files (1 minute)

Delete Xcode's default files:
- `ContentView.swift` ❌
- `SecureShredderApp.swift` ❌

Drag these folders into Xcode:
- ✅ `SecureShredder/SecureShredder/` (entire folder)

Uncheck "Copy items if needed" ⚠️

### 3. Add Finder Extension (1 minute)

```
File → New → Target
→ macOS → Action Extension
→ Name: "ShredderQuickAction"
→ Delete default ActionViewController.swift
→ Drag in ShredderQuickAction/ files
```

### 4. Configure (1 minute)

**Main App:**
- Signing & Capabilities → Add "App Sandbox"
- File Access → User Selected Files: Read/Write

**Extension:**
- Same as above

### 5. Build & Run

```
⌘B (Build)
⌘R (Run)
```

## File Checklist

Make sure these files are in your Xcode project:

**Main App (SecureShredder target):**
```
✓ SecureShredderApp.swift
✓ Models/ShredConfiguration.swift
✓ Models/FileItem.swift
✓ Models/ShredResult.swift
✓ Models/ShredOperation.swift
✓ Core/DoDPattern.swift
✓ Core/FileOverwriter.swift
✓ Core/FileDiscovery.swift
✓ Core/SecureDeletion.swift
✓ Core/ShredEngine.swift
✓ ViewModels/MainViewModel.swift
✓ Views/MainView.swift
✓ Views/DropZoneView.swift
✓ Views/ConfirmationView.swift
✓ Views/ProgressView.swift
✓ Views/Components/WarningBannerView.swift
✓ Info.plist
✓ SecureShredder.entitlements
```

**Extension (ShredderQuickAction target):**
```
✓ ActionRequestHandler.swift
✓ Info.plist
```

## First Run

After building, you should see:

🟠 Orange warning banner about APFS/SSD limitations
📦 Drop zone for files/folders
🎚️ Pass selector (1, 3, 7, 35)
🔴 Red "Shred Files" button

## Testing

1. **Drag a test file** onto the drop zone
2. **Click "Shred Files"**
3. **Confirm** the operation
4. **Watch progress** bar
5. **Verify** file is deleted

## Troubleshooting

**Build fails?**
- Clean Build Folder: ⇧⌘K
- Check all files are added to correct targets

**Can't write files?**
- Verify entitlements are configured
- Check App Sandbox is enabled with User Selected Files

**Finder action doesn't show?**
- Extension may need system restart
- Check: System Settings → Extensions → Finder

## Next Steps

- Read [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed configuration
- Read [README.md](README.md) for technical details
- Add custom app icon (optional)
- Test with various file types

---

**Need help?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete step-by-step instructions.
