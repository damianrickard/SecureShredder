# SecureShredder - Complete Setup Guide

This guide will walk you through setting up the SecureShredder Xcode project from the provided source files.

## Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+ installed
- Basic familiarity with Xcode

## Step-by-Step Setup

### Step 1: Create New Xcode Project

1. Open **Xcode**
2. Select **File → New → Project** (or ⇧⌘N)
3. In the template chooser:
   - Select **macOS** tab
   - Choose **App** template
   - Click **Next**

4. Configure the project:
   - **Product Name**: `SecureShredder`
   - **Team**: Select your development team (or None for local dev)
   - **Organization Identifier**: `com.yourname` (or any identifier)
   - **Bundle Identifier**: Will auto-populate as `com.yourname.SecureShredder`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Use Core Data**: Unchecked
   - **Include Tests**: Optional (we'll add custom tests later)
   - Click **Next**

5. Choose location:
   - Navigate to: `/Users/damianrickard/coding/SecureShredder`
   - Click **Create**
   - If asked about Git, choose your preference

### Step 2: Remove Default Files

Xcode creates some default files we don't need:

1. In the Project Navigator (left sidebar), find these files:
   - `ContentView.swift` - **Delete** (Move to Trash)
   - `SecureShredderApp.swift` - **Delete** (we have our own)

### Step 3: Add Source Files

Now we'll add all our custom source files:

1. In Finder, navigate to: `/Users/damianrickard/coding/SecureShredder/SecureShredder/SecureShredder`

2. You should see these folders:
   - `Models/`
   - `Core/`
   - `ViewModels/`
   - `Views/`
   - `Utilities/`
   - Plus: `SecureShredderApp.swift`, `Info.plist`, `SecureShredder.entitlements`

3. **Drag all folders and files** into Xcode's Project Navigator
   - Drop them under the "SecureShredder" group (blue folder icon)
   - In the dialog that appears:
     - ✅ **Copy items if needed**: **UNCHECK** this (important!)
     - **Added folders**: Select "Create groups"
     - **Add to targets**: Check "SecureShredder"
   - Click **Finish**

4. Your project structure should now look like:
   ```
   SecureShredder (project)
   ├── SecureShredder (group)
   │   ├── SecureShredderApp.swift
   │   ├── Models/
   │   │   ├── ShredConfiguration.swift
   │   │   ├── FileItem.swift
   │   │   ├── ShredResult.swift
   │   │   └── ShredOperation.swift
   │   ├── Core/
   │   │   ├── DoDPattern.swift
   │   │   ├── FileOverwriter.swift
   │   │   ├── FileDiscovery.swift
   │   │   ├── SecureDeletion.swift
   │   │   └── ShredEngine.swift
   │   ├── ViewModels/
   │   │   └── MainViewModel.swift
   │   ├── Views/
   │   │   ├── MainView.swift
   │   │   ├── DropZoneView.swift
   │   │   ├── ConfirmationView.swift
   │   │   ├── ProgressView.swift
   │   │   └── Components/
   │   │       └── WarningBannerView.swift
   │   ├── Info.plist
   │   └── SecureShredder.entitlements
   ```

### Step 4: Configure Info.plist

1. In Project Navigator, select the **project** (top item, blue icon)
2. Select the **SecureShredder target** (under TARGETS)
3. Go to the **Info** tab
4. Look for **Custom macOS Application Target Properties**

5. Add URL Scheme:
   - Click **+** to add a new entry
   - Select **URL types** (array)
   - Expand it, add **Item 0** (dictionary)
   - Under Item 0, add:
     - **URL identifier**: `com.secureshredder.url`
     - **URL Schemes** (array):
       - **Item 0**: `secureshredder`

6. Or simply replace with provided Info.plist:
   - Right-click `Info.plist` in navigator → Delete → "Move to Trash"
   - Drag the provided `Info.plist` from Finder

### Step 5: Configure Entitlements

1. In Project Navigator, select the **project**
2. Select **SecureShredder target**
3. Go to **Signing & Capabilities** tab

4. Enable App Sandbox:
   - Click **+ Capability** button
   - Search for **App Sandbox**
   - Click to add it

5. Configure File Access:
   - Under **File Access**, find **User Selected Files**
   - Change to **Read/Write**

6. Or use provided entitlements file:
   - The `SecureShredder.entitlements` file is already configured
   - Xcode should automatically detect and use it

### Step 6: Add Action Extension (Finder Integration)

This step adds the right-click Finder menu integration.

1. **Create Extension Target**:
   - File → New → Target
   - Select **macOS** tab
   - Choose **Action Extension**
   - Click **Next**

2. **Configure Extension**:
   - **Product Name**: `ShredderQuickAction`
   - **Language**: Swift
   - **Project**: SecureShredder
   - Click **Finish**
   - When asked "Activate 'ShredderQuickAction' scheme?": Click **Cancel** (stay on SecureShredder scheme)

3. **Remove Default Files**:
   - In Project Navigator, expand **ShredderQuickAction** folder
   - Delete `ActionViewController.swift` (we don't need it)

4. **Add Custom Handler**:
   - In Finder, navigate to `/Users/damianrickard/coding/SecureShredder/SecureShredder/ShredderQuickAction/`
   - Drag `ActionRequestHandler.swift` into Xcode under the **ShredderQuickAction** group
   - Ensure it's added to the **ShredderQuickAction target** (not SecureShredder)

5. **Replace Info.plist**:
   - Delete the auto-generated `Info.plist` in the ShredderQuickAction folder
   - Drag the provided `ShredderQuickAction/Info.plist` from Finder
   - Add to target: **ShredderQuickAction**

### Step 7: Configure Extension Entitlements

1. Select **ShredderQuickAction target**
2. Go to **Signing & Capabilities**
3. Add **App Sandbox** capability (same as Step 5)
4. Set **User Selected Files** to **Read/Write**

### Step 8: Build Settings (Optional but Recommended)

1. Select **project** → **SecureShredder target** → **Build Settings**
2. Search for "swift" → Find **Swift Language Version**
   - Ensure it's set to **Swift 5** or later

3. Search for "deployment" → Find **macOS Deployment Target**
   - Set to **13.0** (macOS Ventura)

4. Search for "arch" → Find **Architectures**
   - Should be set to **$(ARCHS_STANDARD)** (includes both Intel and Apple Silicon)

### Step 9: Test Build

1. Select **Product → Build** (or ⌘B)
2. Wait for build to complete
3. Check for any errors in the **Issue Navigator** (⌘5)

Expected result: **Build Succeeded** ✅

### Step 10: Run the App

1. Ensure **SecureShredder** scheme is selected (top-left dropdown)
2. Select **Product → Run** (or ⌘R)
3. The app should launch with:
   - Orange warning banner about APFS/SSD limitations
   - Drag-drop zone
   - Pass selector (1, 3, 7, 35)
   - "Shred Files" button

### Step 11: Test Finder Integration

The Finder Quick Action requires the app to be in `/Applications` or registered:

1. **Build for Testing**:
   - Product → Build (⌘B)

2. **Copy to Applications** (optional):
   ```bash
   cp -r ~/Library/Developer/Xcode/DerivedData/SecureShredder-*/Build/Products/Debug/SecureShredder.app /Applications/
   ```

3. **Test Quick Action**:
   - Open Finder
   - Right-click any file
   - Look for "Quick Actions" → "Secure Shred"
   - Note: May require logging out/in for first use

4. **Alternatively**: For development, just use the main app with drag-drop

## Troubleshooting

### Build Errors

**"Cannot find 'XXX' in scope"**
- Ensure all `.swift` files are added to the **SecureShredder target**
- Check: Right-click file → Show File Inspector → Target Membership

**"Missing required module 'SwiftUI'"**
- Go to Build Settings → Search "framework"
- Ensure SwiftUI.framework is linked

**Entitlements warnings**
- Ensure both main app and extension have correct entitlements
- Both need App Sandbox + User Selected Files (Read/Write)

### Runtime Issues

**"Operation not permitted" when shredding**
- The app needs user-selected file access
- Ensure files are dragged in or selected via file picker
- Check entitlements are properly configured

**Quick Action doesn't appear**
- Extension may not be registered yet
- Try: System Settings → Extensions → Finder → Enable "Secure Shred"
- May require logout/login

**App crashes on launch**
- Check Console.app for crash logs
- Verify all Swift files compiled successfully
- Ensure Info.plist is valid XML

## Advanced: Command-Line Build

Once set up in Xcode, you can build from terminal:

```bash
cd /Users/damianrickard/coding/SecureShredder

# Build
xcodebuild -project SecureShredder.xcodeproj \
  -scheme SecureShredder \
  -configuration Release \
  build

# Run
open ~/Library/Developer/Xcode/DerivedData/SecureShredder-*/Build/Products/Release/SecureShredder.app
```

## Next Steps

- [ ] Test with various file types and sizes
- [ ] Verify progress tracking works correctly
- [ ] Test cancellation
- [ ] Test with locked files
- [ ] Add unit tests (optional)
- [ ] Customize app icon
- [ ] Create installer/distribution build

## Support

If you encounter issues:

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Quit Xcode** and reopen
3. **Delete Derived Data**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/SecureShredder-*
   ```
4. **Check Console.app** for system errors
5. **Review build logs** in Report Navigator (⌘9)

---

**Ready to build!** Follow these steps and you'll have a working SecureShredder app.

For detailed technical information, see [README.md](README.md).
