#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
TARGET_DIR="${HERMES_HOME}/hermes-agent/ui-tui"
BACKUP_DIR="${HERMES_HOME}/backups"
SKINS_DIR="${HERMES_HOME}/skins"
SKIN_NAME="custom"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# hermes version string (includes commit info, so it changes on hermes update). Obtained the same way as in uninstall.sh
hermes_version() {
  local v=""
  if command -v hermes >/dev/null 2>&1; then
    v=$(hermes --version 2>/dev/null | head -n 1) || true
  fi
  if [ -z "$v" ] && [ -d "$HERMES_HOME/hermes-agent/.git" ]; then
    v="git $(git -C "$HERMES_HOME/hermes-agent" rev-parse HEAD 2>/dev/null)" || v=""
  fi
  printf '%s' "$v"
}

echo "[install.sh] Starting hermes-custom-tui installation..."
mkdir -p "$BACKUP_DIR"

# 1. Back up the existing ui-tui (excluding dist, node_modules) + record the hermes version at backup time
if [ -d "$TARGET_DIR" ]; then
  BACKUP_FILE="$BACKUP_DIR/ui-tui-pre-custom-$TIMESTAMP.tar.gz"
  echo "[install.sh] Creating backup of existing ui-tui: $BACKUP_FILE"
  tar --exclude='node_modules' --exclude='dist' -czf "$BACKUP_FILE" -C "$(dirname "$TARGET_DIR")" ui-tui
  echo "$BACKUP_FILE" > "$BACKUP_DIR/latest_ui_tui_backup.txt"
  HERMES_VERSION=$(hermes_version)
  printf '%s\n' "$HERMES_VERSION" > "${BACKUP_FILE%.tar.gz}.version"
  echo "[install.sh] Recorded hermes version: ${HERMES_VERSION:-(unknown)}"
fi

# 2. Back up the existing theme state (uninstall.sh pairs it by the same TIMESTAMP)
#    - skin-pre-custom-<TS>.env  : theme name, previously active theme, whether the theme file existed
#    - skin-pre-custom-<TS>.yaml : existing custom.yaml (if it existed)
SKIN_STATE="$BACKUP_DIR/skin-pre-custom-$TIMESTAMP"
SKIN_FILE_EXISTED=0
if [ -f "$SKINS_DIR/$SKIN_NAME.yaml" ]; then
  SKIN_FILE_EXISTED=1
  cp -p "$SKINS_DIR/$SKIN_NAME.yaml" "$SKIN_STATE.yaml"
  echo "[install.sh] Backed up existing theme file: $SKIN_STATE.yaml"
fi
PREV_SKIN=""
if command -v hermes >/dev/null 2>&1; then
  PREV_SKIN=$(hermes config get display.skin 2>/dev/null) || PREV_SKIN="default"
fi
printf 'SKIN_NAME=%q\nSKIN_FILE_EXISTED=%s\nPREV_SKIN=%q\n' "$SKIN_NAME" "$SKIN_FILE_EXISTED" "$PREV_SKIN" > "$SKIN_STATE.env"

# 3. Sync this repository -> ~/.hermes/hermes-agent/ui-tui (excluding node_modules, dist, .git, skins)
echo "[install.sh] Syncing source files: $SOURCE_DIR -> $TARGET_DIR"
mkdir -p "$TARGET_DIR"
rsync -av --delete --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='skins' "$SOURCE_DIR/" "$TARGET_DIR/"

# 4. Install and apply the theme
echo "[install.sh] Installing theme: $SKINS_DIR/$SKIN_NAME.yaml"
mkdir -p "$SKINS_DIR"
cp "$SOURCE_DIR/skins/$SKIN_NAME.yaml" "$SKINS_DIR/$SKIN_NAME.yaml"
if command -v hermes >/dev/null 2>&1; then
  hermes skin use "$SKIN_NAME"
else
  echo "[install.sh] Warning: hermes command not found, so the theme was not applied. Run 'hermes skin use $SKIN_NAME' manually." >&2
fi

# 5. Build in the ~/.hermes/hermes-agent context
echo "[install.sh] Building ui-tui..."
cd "$TARGET_DIR"
node ../scripts/build/tui.mjs

echo "[install.sh] Installation and build completed successfully!"
