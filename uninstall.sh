#!/usr/bin/env bash
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-${HOME}/.hermes}"
TARGET_DIR="${HERMES_HOME}/hermes-agent/ui-tui"
BACKUP_DIR="${HERMES_HOME}/backups"
SKINS_DIR="${HERMES_HOME}/skins"
SKIN_NAME="custom"

# hermes version string (obtained the same way as in install.sh)
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

echo "[uninstall.sh] Removing hermes-custom-tui and restoring the original..."

# 1. Collect backups (newest first)
BACKUPS=()
while IFS= read -r f; do
  BACKUPS+=("$f")
done < <(ls -t "$BACKUP_DIR"/ui-tui-*.tar.gz 2>/dev/null || true)

if [ "${#BACKUPS[@]}" -eq 0 ]; then
  echo "[uninstall.sh] Error: no backup file (.tar.gz) found to restore." >&2
  exit 1
fi

# 2. Choose the backup to restore (proceed without asking if there is only one)
if [ "${#BACKUPS[@]}" -eq 1 ]; then
  BACKUP_FILE="${BACKUPS[0]}"
else
  # Default: the backup referenced by latest_ui_tui_backup.txt, otherwise the most recent one
  LATEST_BACKUP_TXT="$BACKUP_DIR/latest_ui_tui_backup.txt"
  LATEST=""
  [ -f "$LATEST_BACKUP_TXT" ] && LATEST=$(cat "$LATEST_BACKUP_TXT")
  DEFAULT=1
  for i in "${!BACKUPS[@]}"; do
    if [ "${BACKUPS[$i]}" = "$LATEST" ]; then
      DEFAULT=$((i + 1))
    fi
  done

  echo "[uninstall.sh] Select a backup to restore (newest first):"
  for i in "${!BACKUPS[@]}"; do
    MARK=""
    [ $((i + 1)) -eq "$DEFAULT" ] && MARK="  (default)"
    printf "  %2d) %s%s\n" $((i + 1)) "$(basename "${BACKUPS[$i]}")" "$MARK"
  done

  while true; do
    printf "Enter number [default: %d]: " "$DEFAULT"
    CHOICE=""
    read -r CHOICE || true
    CHOICE="${CHOICE:-$DEFAULT}"
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#BACKUPS[@]}" ]; then
      break
    fi
    echo "[uninstall.sh] Enter a number between 1 and ${#BACKUPS[@]}."
  done
  BACKUP_FILE="${BACKUPS[$((CHOICE - 1))]}"
fi

echo "[uninstall.sh] Backup to restore: $BACKUP_FILE"

# 3. Check the hermes version (prevents overwriting with an older ui-tui after install → hermes update → uninstall)
VERSION_FILE="${BACKUP_FILE%.tar.gz}.version"
if [ -f "$VERSION_FILE" ]; then
  BACKUP_VERSION=$(head -n 1 "$VERSION_FILE")
  CURRENT_VERSION=$(hermes_version)
  if [ -n "$BACKUP_VERSION" ] && [ "$BACKUP_VERSION" != "$CURRENT_VERSION" ]; then
    echo "[uninstall.sh] Warning: the hermes version differs from when the backup was made." >&2
    echo "  At backup: $BACKUP_VERSION" >&2
    echo "  Current:   ${CURRENT_VERSION:-(unknown)}" >&2
    echo "  Restoring will overwrite ui-tui with an older version that may not match the current hermes, and the build or runtime may fail." >&2
    printf "Restore anyway? [y/N]: "
    ANSWER=""
    read -r ANSWER || true
    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
      echo "[uninstall.sh] Restore cancelled."
      exit 1
    fi
  fi
else
  echo "[uninstall.sh] This backup has no hermes version info; skipping the version check."
fi

# 4. Restore ui-tui
tar -xzf "$BACKUP_FILE" -C "$(dirname "$TARGET_DIR")"

# 5. Restore the theme (only if theme state with the same TIMESTAMP as the selected backup exists)
BACKUP_NAME=$(basename "$BACKUP_FILE")
#    ui-tui-pre-<TAG>-<TS>.tar.gz ↔ skin-pre-<TAG>-<TS>.env. Also handles backups made before the rename (TAG=claude)
TIMESTAMP="${BACKUP_NAME#ui-tui-pre-*-}"
TIMESTAMP="${TIMESTAMP%.tar.gz}"
TAG="${BACKUP_NAME#ui-tui-pre-}"
TAG="${TAG%%-*}"
SKIN_STATE="$BACKUP_DIR/skin-pre-$TAG-$TIMESTAMP"
if [ "$TIMESTAMP" != "${BACKUP_NAME%.tar.gz}" ] && [ -f "$SKIN_STATE.env" ]; then
  SKIN_FILE_EXISTED=0
  PREV_SKIN=""
  # Older backups' .env has no SKIN_NAME → restore using the theme name at that time (claude-code)
  [ "$TAG" = "claude" ] && SKIN_NAME="claude-code"
  # shellcheck source=/dev/null
  . "$SKIN_STATE.env"
  if [ "$SKIN_FILE_EXISTED" = "1" ] && [ -f "$SKIN_STATE.yaml" ]; then
    echo "[uninstall.sh] Restoring existing theme file: $SKINS_DIR/$SKIN_NAME.yaml"
    mkdir -p "$SKINS_DIR"
    cp -p "$SKIN_STATE.yaml" "$SKINS_DIR/$SKIN_NAME.yaml"
  else
    echo "[uninstall.sh] Removing theme file that did not exist before install: $SKINS_DIR/$SKIN_NAME.yaml"
    rm -f "$SKINS_DIR/$SKIN_NAME.yaml"
  fi
  if [ -n "$PREV_SKIN" ]; then
    if command -v hermes >/dev/null 2>&1; then
      echo "[uninstall.sh] Applying previous theme: $PREV_SKIN"
      hermes skin use "$PREV_SKIN"
    else
      echo "[uninstall.sh] Warning: hermes command not found. Run 'hermes skin use $PREV_SKIN' manually." >&2
    fi
  fi
else
  echo "[uninstall.sh] This backup has no theme backup info; skipping theme restore."
fi

# 6. Rebuild
echo "[uninstall.sh] Original restored! Building ui-tui..."
cd "$TARGET_DIR"
node ../scripts/build/tui.mjs

echo "[uninstall.sh] Original restored and rebuilt successfully."
