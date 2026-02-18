//
//  SecureShredderApp.swift
//  SecureShredder
//
//  Main app entry point
//

import SwiftUI
import AppKit

/// AppDelegate to handle Services menu and file opening
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register as a Services provider
        NSApp.servicesProvider = self
    }

    /// Handle files opened via "Open With" or drag-and-drop to dock icon
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }

        // Build URL scheme to pass files to the app
        let paths = urls.map { $0.path }
        guard let jsonData = try? JSONEncoder().encode(paths),
              let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let schemeURL = URL(string: "secureshredder://shred?files=\(base64)") else {
            return
        }

        // Open URL to trigger onOpenURL handler
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSWorkspace.shared.open(schemeURL)
        }
    }

    /// Service handler for "Secure Shred" from Finder context menu
    /// The selector must match NSMessage in Info.plist: shredFiles:userData:error:
    @objc(shredFiles:userData:error:)
    func shredFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        // Try multiple methods to get file paths from pasteboard
        var paths: [String] = []

        // Method 1: Try reading file URLs
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            paths = urls.map { $0.path }
        }

        // Method 2: Try NSFilenamesPboardType (legacy but works with Finder)
        if paths.isEmpty, let filenames = pboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            paths = filenames
        }

        // Method 3: Try public.file-url
        if paths.isEmpty, let urlStrings = pboard.propertyList(forType: NSPasteboard.PasteboardType("public.file-url")) as? [String] {
            paths = urlStrings.compactMap { URL(string: $0)?.path }
        }

        guard !paths.isEmpty else {
            error.pointee = "No files provided" as NSString
            return
        }

        // Build URL scheme to pass files to the app
        guard let jsonData = try? JSONEncoder().encode(paths),
              let base64 = jsonData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let schemeURL = URL(string: "secureshredder://shred?files=\(base64)") else {
            error.pointee = "Failed to encode file paths" as NSString
            return
        }

        // Open URL to trigger onOpenURL handler
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSWorkspace.shared.open(schemeURL)
        }
    }
}

@main
struct SecureShredderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Remove unwanted menu items
            CommandGroup(replacing: .newItem) { }
        }
    }
}
