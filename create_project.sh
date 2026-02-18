#!/bin/bash

# Script to create SecureShredder Xcode project
# This creates a basic macOS app project structure

set -e

PROJECT_DIR="SecureShredder"
PROJECT_NAME="SecureShredder"

echo "Creating Xcode project for $PROJECT_NAME..."

# Create project directory structure
cd "$(dirname "$0")"

# Check if we're in the right directory
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: $PROJECT_DIR directory not found"
    exit 1
fi

cd "$PROJECT_DIR"

# Create the xcodeproj bundle
mkdir -p "${PROJECT_NAME}.xcodeproj"
mkdir -p "${PROJECT_NAME}.xcodeproj/project.xcworkspace"
mkdir -p "${PROJECT_NAME}.xcodeproj/xcuserdata"

echo "Xcode project structure created!"
echo ""
echo "To complete the setup:"
echo "1. Open Xcode"
echo "2. File > New > Project"
echo "3. Choose 'macOS > App'"
echo "4. Name it 'SecureShredder'"
echo "5. Interface: SwiftUI"
echo "6. Language: Swift"
echo "7. Save to: $(pwd)"
echo "8. Choose 'Replace' when prompted"
echo ""
echo "Then:"
echo "9. Add all the Swift files from the SecureShredder, Models, Core, Views, ViewModels folders"
echo "10. File > New > Target > Action Extension (name: ShredderQuickAction)"
echo "11. Add ActionRequestHandler.swift to the extension target"
echo "12. Configure entitlements and Info.plist as provided"
echo ""
echo "All source files are ready in their respective directories!"
