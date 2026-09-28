#!/bin/sh
# Assemble RudeClaude.app : l'app de barre des menus et le binaire rudeclaude.
set -eu
cd "$(dirname "$0")"

app=build/RudeClaude.app
swift build -c release --package-path RudeClaudeBar
bin=$(swift build -c release --package-path RudeClaudeBar --show-bin-path)

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/"
cp "$bin/RudeClaudeBar" "$app/Contents/MacOS/"
(cd .. && go build -o "macos/$app/Contents/MacOS/rudeclaude" .)
codesign --force --deep --sign - "$app"

echo "→ $(pwd)/$app"
