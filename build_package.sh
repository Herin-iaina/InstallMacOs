#!/bin/bash

# Configuration
PACKAGE_NAME="macOS_Installer"
PACKAGE_VERSION="1.0"
PACKAGE_ID="com.smartelia.macosinstaller"
INSTALL_LOCATION="/usr/local/bin"
SCRIPT_NAME="macos_installer_client.sh"

# Créer le dossier temporaire pour la construction
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"

# Copier le script dans le dossier de build
cp "$SCRIPT_NAME" "$BUILD_DIR/"

# Créer le package
pkgbuild \
    --root "$BUILD_DIR" \
    --install-location "$INSTALL_LOCATION" \
    --identifier "$PACKAGE_ID" \
    --version "$PACKAGE_VERSION" \
    --scripts scripts \
    "$PACKAGE_NAME.pkg"

# Nettoyer
rm -rf "$BUILD_DIR"

echo "Package créé : $PACKAGE_NAME.pkg" 