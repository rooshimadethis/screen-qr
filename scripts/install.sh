#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != "--update" ) ]]; then
  echo "Usage: bash scripts/install.sh [--update]"
  exit 1
fi
app="$HOME/Applications/Screen QR.app"
if [[ -L "$app" || ( -e "$app" && ! -d "$app" ) ]]; then
  echo "Refusing to replace a symlink or non-directory at the install location."
  exit 1
fi
if [[ -e "$app" ]]; then
  if [[ "${1:-}" != "--update" ]]; then
    echo "Already installed. Use --update to preserve a backup and install the new version."
    exit 1
  fi
  bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
  if [[ "$bundle_id" != "local.rooshi.screenqr" ]]; then
    echo "Refusing to replace an unrelated app."
    exit 1
  fi
fi
bash scripts/build.sh
mkdir -p "$HOME/Applications"
# Copy and verify before moving a working installation. Staging stays on the
# destination filesystem so the final move publishes a complete app bundle.
staging_dir=$(mktemp -d "$HOME/Applications/.screenqr-install.XXXXXX")
staged_app="$staging_dir/Screen QR.app"
ditto 'build/DerivedData/Build/Products/Release/Screen QR.app' "$staged_app"
codesign --verify --deep --strict "$staged_app"
backup=""
restore_on_failure() {
  status=$?
  if [[ $status -ne 0 && -n "$backup" && ! -e "$app" && ! -L "$app" ]]; then
    if mv "$backup" "$app"; then
      echo "Restored the previous installation."
    else
      echo "Automatic restore failed; the previous app is preserved at $backup"
    fi
  fi
  exit "$status"
}
trap restore_on_failure EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ -e "$app" ]]; then
  mkdir -p "$PWD/build/backups"
  backup_dir=$(mktemp -d "$PWD/build/backups/update-XXXXXX")
  backup="$backup_dir/Screen QR.app"
  mv "$app" "$backup"
  echo "Previous app preserved at $backup"
fi
mv "$staged_app" "$app"
rmdir "$staging_dir"
if [[ ! -e "$HOME/Desktop/Screen QR.app" && ! -L "$HOME/Desktop/Screen QR.app" ]]; then
  ln -s "$app" "$HOME/Desktop/Screen QR.app"
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
pluginkit -a "$app/Contents/PlugIns/ScreenQRControls.appex"
codesign --verify --deep --strict "$app"
echo "Installed Screen QR with its native Control Center extension and Desktop shortcut."
