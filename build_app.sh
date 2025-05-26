#!/bin/bash

# Configuration
APP_NAME="macOS_downloader"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Créer la structure de l'application
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compiler le code Swift
swiftc InstallerApp/main.swift -o "$MACOS_DIR/$APP_NAME"

# Copier Info.plist
cp InstallerApp/Info.plist "$CONTENTS_DIR/"

# Créer le package
pkgbuild \
    --root "$BUILD_DIR" \
    --install-location "/Applications" \
    --identifier "com.smartelia.macosinstaller" \
    --version "1.0" \
    "$APP_NAME.pkg"

echo "Application créée : $APP_NAME.pkg" 