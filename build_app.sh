#!/bin/bash

# Configuration
APP_NAME="macOS_downloader"
BUILD_DIR="build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Nettoyer le dossier de build
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copier le script shell
cp InstallerApp/installer.sh "$MACOS_DIR/$APP_NAME"
chmod 755 "$MACOS_DIR/$APP_NAME"

# Copier Info.plist
cp InstallerApp/Info.plist "$CONTENTS_DIR/"

# Créer le dossier scripts s'il n'existe pas
mkdir -p scripts

# Créer le script postinstall
cat > scripts/postinstall << 'EOF'
#!/bin/bash

# Définir les permissions d'exécution sur l'application
chmod 755 "/Applications/macOS_downloader.app/Contents/MacOS/macOS_downloader"

# Créer le dossier de logs avec les bonnes permissions
mkdir -p /var/tmp
chmod 777 /var/tmp

# Vérifier et installer unzip si nécessaire
if ! command -v unzip &> /dev/null; then
    echo "Installation de unzip..."
    if command -v brew &> /dev/null; then
        brew install unzip
    else
        echo "Homebrew non trouvé. Veuillez installer unzip manuellement."
    fi
fi

exit 0
EOF

chmod 755 scripts/postinstall

# Créer le package directement avec pkgbuild
pkgbuild \
    --root "$BUILD_DIR" \
    --install-location "/Applications" \
    --identifier "com.smartelia.macosinstaller" \
    --version "1.0" \
    --scripts scripts \
    --ownership preserve \
    "$APP_NAME.pkg"

echo "Application créée : $APP_NAME.pkg" 