#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------
# build-app.sh — Compiles Deepseek-Balance and wraps it into
#                a standalone macOS .app bundle.
# -----------------------------------------------------------

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
BINARY_NAME="DeepseekBalance"
APP_NAME="Deepseek-Balance"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BINARY="$BUILD_DIR/arm64-apple-macosx/release/$BINARY_NAME"

echo "=== Building Deepseek-Balance ==="

# 1. Build the Swift package in release mode
cd "$PROJECT_DIR"
/usr/bin/swift build -c release --arch arm64 2>&1

echo ""
echo "=== Creating .app bundle ==="

# 2. Create the .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy the binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 3b. Copy menu bar icon into the bundle so Bundle.main finds it
#     without triggering a macOS TCC file-access prompt.
if [ -f "$PROJECT_DIR/Sources/DeepseekBalance/Resources/deepseek.png" ]; then
    cp "$PROJECT_DIR/Sources/DeepseekBalance/Resources/deepseek.png" \
       "$APP_BUNDLE/Contents/Resources/deepseek.png"
    echo "  ✓ Copied deepseek.png into bundle"
fi

# 4. Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Deepseek-Balance</string>
    <key>CFBundleIdentifier</key>
    <string>com.deepseek.balance</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Deepseek-Balance</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# 5. Copy a simple app icon (generate a 1024x1024 PNG via sips)
ICON_DIR="$BUILD_DIR/icon.iconset"
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"

# Generate a simple solid icon via a tiny Swift helper
cat > /tmp/gen_icon.swift << 'SWIFT'
import AppKit

let size = NSSize(width: 1024, height: 1024)
let img = NSImage(size: size, flipped: false) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Background circle — DeepSeek blue
    ctx.setFillColor(CGColor(red: 0.29, green: 0.55, blue: 0.91, alpha: 1.0))
    ctx.fillEllipse(in: rect)

    // White whale tail in center
    let inset: CGFloat = 200
    let r = rect.insetBy(dx: inset, dy: inset)
    let path = CGMutablePath()
    let w = r.width
    let h = r.height
    let ox = r.origin.x
    let oy = r.origin.y

    path.move(to:     CGPoint(x: ox + w * 0.50, y: oy + h * 0.15))
    path.addCurve(to: CGPoint(x: ox + w * 0.12, y: oy + h * 0.50),
                  control1: CGPoint(x: ox + w * 0.42, y: oy + h * 0.15),
                  control2: CGPoint(x: ox + w * 0.15, y: oy + h * 0.25))
    path.addCurve(to: CGPoint(x: ox + w * 0.50, y: oy + h * 0.55),
                  control1: CGPoint(x: ox + w * 0.08, y: oy + h * 0.72),
                  control2: CGPoint(x: ox + w * 0.50, y: oy + h * 0.55))
    path.addCurve(to: CGPoint(x: ox + w * 0.88, y: oy + h * 0.50),
                  control1: CGPoint(x: ox + w * 0.50, y: oy + h * 0.55),
                  control2: CGPoint(x: ox + w * 0.92, y: oy + h * 0.72))
    path.addCurve(to: CGPoint(x: ox + w * 0.50, y: oy + h * 0.15),
                  control1: CGPoint(x: ox + w * 0.85, y: oy + h * 0.25),
                  control2: CGPoint(x: ox + w * 0.58, y: oy + h * 0.15))
    path.closeSubpath()

    ctx.addPath(path)
    ctx.setFillColor(CGColor.white)
    ctx.fillPath()

    return true
}

guard let tiff = img.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to encode icon")
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: "/tmp/appicon_1024.png"))
SWIFT

swift /tmp/gen_icon.swift 2>/dev/null

if [ -f /tmp/appicon_1024.png ]; then
    # Generate all required icon sizes
    sips -z 16 16   /tmp/appicon_1024.png --out "$ICON_DIR/icon_16x16.png"        &>/dev/null
    sips -z 32 32   /tmp/appicon_1024.png --out "$ICON_DIR/icon_16x16@2x.png"     &>/dev/null
    sips -z 32 32   /tmp/appicon_1024.png --out "$ICON_DIR/icon_32x32.png"        &>/dev/null
    sips -z 64 64   /tmp/appicon_1024.png --out "$ICON_DIR/icon_32x32@2x.png"     &>/dev/null
    sips -z 128 128 /tmp/appicon_1024.png --out "$ICON_DIR/icon_128x128.png"      &>/dev/null
    sips -z 256 256 /tmp/appicon_1024.png --out "$ICON_DIR/icon_128x128@2x.png"   &>/dev/null
    sips -z 256 256 /tmp/appicon_1024.png --out "$ICON_DIR/icon_256x256.png"      &>/dev/null
    sips -z 512 512 /tmp/appicon_1024.png --out "$ICON_DIR/icon_256x256@2x.png"   &>/dev/null
    sips -z 512 512 /tmp/appicon_1024.png --out "$ICON_DIR/icon_512x512.png"      &>/dev/null
    sips -z 1024 1024 /tmp/appicon_1024.png --out "$ICON_DIR/icon_512x512@2x.png" &>/dev/null

    iconutil -c icns "$ICON_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null
    rm -f /tmp/appicon_1024.png /tmp/gen_icon.swift
    echo "  ✓ App icon generated"
else
    echo "  ⚠ Could not generate icon (non‑critical)"
fi

rm -f /tmp/gen_icon.swift

echo ""
echo "=== Build complete ==="
echo "App: $APP_BUNDLE"
echo ""
echo "To run: open '$APP_BUNDLE'"
echo "Or:     $APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 6. Create DMG installer
echo ""
echo "=== Creating DMG installer ==="

DMG_DIR="$BUILD_DIR/dmg"
DMG_FILE="$BUILD_DIR/$APP_NAME.dmg"
rm -rf "$DMG_DIR" "$DMG_FILE"
mkdir -p "$DMG_DIR"

# Copy app into staging folder
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Create Applications symlink for drag‑to‑install
ln -s /Applications "$DMG_DIR/Applications"

# Build the DMG
/usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_FILE" 2>&1

# Clean up staging
rm -rf "$DMG_DIR"

echo "  ✓ DMG created: $DMG_FILE"
echo ""
echo "Share \`$(basename "$DMG_FILE")\` — users drag Deepseek-Balance.app to /Applications to install."
