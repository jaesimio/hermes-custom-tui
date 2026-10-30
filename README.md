**English** | [한국어](README-ko.md)

# hermes-custom-tui

A version of the Hermes TUI (`ui-tui`) with a custom-styled UI.
`install.sh` replaces the `ui-tui` of your installed Hermes with the source in this repository and applies the `custom` theme ([skins/custom.yaml](skins/custom.yaml)).
`uninstall.sh` restores the original state.

All paths are relative to `$HERMES_HOME`, which defaults to `~/.hermes` when unset.

For the original Hermes TUI documentation, see [README_ORI.md](README_ORI.md).

## Prerequisites

- Hermes must be installed at `~/.hermes/hermes-agent`. The build script `~/.hermes/hermes-agent/scripts/build/tui.mjs` is used.
- `~/.hermes/hermes-agent/ui-tui/node_modules` must already be installed. The scripts do not run `npm install`.
- `node`, `rsync`, `tar`
- The `hermes` command is used to apply the theme. If it is not on your PATH, only the theme file is copied and a warning is printed.

## Install — `install.sh`

```bash
./install.sh
```

Steps:

1. **Backup**: If `~/.hermes/hermes-agent/ui-tui` exists, it is archived (excluding `node_modules` and `dist`) to
   `~/.hermes/backups/ui-tui-pre-custom-<YYYYMMDD_HHMMSS>.tar.gz`.
   The path is recorded in `~/.hermes/backups/latest_ui_tui_backup.txt`.
   The hermes version at backup time (first line of `hermes --version`) is saved alongside it in `ui-tui-pre-custom-<TS>.version`.
2. **Theme state backup**: The following files are saved with the same timestamp:
   - `skin-pre-custom-<TS>.env`: the previously active theme (`display.skin`) and whether a theme file already existed
   - `skin-pre-custom-<TS>.yaml`: the existing `~/.hermes/skins/custom.yaml` (only if it existed)
3. **Sync**: Files in this repository are copied to `~/.hermes/hermes-agent/ui-tui` with `rsync --delete`.
   `.git`, `node_modules`, `dist`, and `skins` are excluded; any other files that exist only in the target are deleted.
4. **Theme install/apply**: `skins/custom.yaml` is copied to `~/.hermes/skins/` and applied with `hermes skin use custom`.
5. **Build**: `node ../scripts/build/tui.mjs` is run in the target directory.

After installation, run `hermes --tui` as usual.

> **Note**: Each run of `install.sh` creates a new backup of the current `ui-tui` and overwrites `latest_ui_tui_backup.txt`.
> If you run it again while already installed, the latest backup will be **the previous hermes-custom-tui version, not the original**.
> To return to the original, choose the oldest backup when running `uninstall.sh`.

## Background color

The background color is set in the skin, not in code. Set `colors.background` in the active skin's `~/.hermes/skins/<skin>.yaml`
(for the bundled theme, [skins/custom.yaml](skins/custom.yaml); it is commented out by default).

```yaml
colors:
  background: "#18181b"
```

- When set, the TUI paints the terminal background with this color (OSC 11) and derives panel/status bar surfaces from it.
  Light/dark mode is also decided by this color instead of terminal detection.
- When unset, the terminal's own background is kept (useful for transparent terminals).
- Restart `hermes --tui` after changing it.
- `install.sh` overwrites `~/.hermes/skins/custom.yaml` with the repository copy, so make permanent changes in `skins/custom.yaml` in this repository.

## Uninstall — `uninstall.sh`

```bash
./uninstall.sh
```

Steps:

1. **Select a backup**: `~/.hermes/backups/ui-tui-*.tar.gz` files are listed newest first; choose one by number.
   - If there is only one backup, it proceeds without asking.
   - Pressing Enter uses the default: the backup referenced by `latest_ui_tui_backup.txt` (the state just before the last `install.sh`), or the most recent backup if that file is missing.
   - If there are no backups, the script exits with an error.

   ```text
   [uninstall.sh] Select a backup to restore (newest first):
      1) ui-tui-pre-custom-20261029_170105.tar.gz  (default)
      2) ui-tui-pre-custom-20261029_154526.tar.gz
   Enter number [default: 1]:
   ```
2. **Check hermes version**: If the hermes version recorded in the backup's `.version` differs from the current one, a warning is shown and you are asked `y/N` whether to continue.
   (This prevents overwriting with an older ui-tui after running `install.sh` → `hermes update` → `uninstall.sh`.)
   - Only `y` proceeds with the restore; Enter or any other input exits without restoring.
   - Backups without a `.version` file (e.g. created before this feature) skip the version check.

   ```text
   [uninstall.sh] Warning: the hermes version differs from when the backup was made.
     At backup: Hermes Agent v0.21.5+9141.ga28a5d0 (2026.9.24) · upstream a28a5d03
     Current:   Hermes Agent v0.21.6+9210.g1b2c3d4 (2026.10.28) · upstream 1b2c3d4e
     Restoring will overwrite ui-tui with an older version that may not match the current hermes, and the build or runtime may fail.
   Restore anyway? [y/N]:
   ```
3. **Restore ui-tui**: The selected backup is extracted into `~/.hermes/hermes-agent/`, overwriting `ui-tui`.
   Extraction only overwrites files, so files newly added by hermes-custom-tui may remain.
   The build only bundles files imported from `src/entry.tsx`, so leftover files do not affect the build.
4. **Restore theme**: If theme state with the same timestamp as the selected backup exists, it is restored.
   - If `custom.yaml` existed before installation, it is restored from the backup; otherwise it is deleted.
   - The previously active theme is re-applied with `hermes skin use <previous theme>`.
   - Backups without theme state (e.g. created before this feature) skip theme restoration.
   - Older `ui-tui-pre-claude-*` backups (from before the theme was renamed to `custom`) are also supported; their theme state restores `claude-code.yaml`.
5. **Build**: `ui-tui/dist/entry.js` is automatically rebuilt with `node ../scripts/build/tui.mjs`.
   If the build fails, the script exits with a failure code.

> To return to the original, select the oldest `ui-tui-pre-custom-*` backup in the list (the bottom one).

## Customizing the mascot — `skins/ascii_chara.txt`

The mascot on the left of the startup banner can be replaced with your own ASCII art via `~/.hermes/skins/ascii_chara.txt`.
This file is not part of this repository; create it yourself. `install.sh` and `uninstall.sh` do not touch it.

```text
color: #d77757
---
 ▐▛███▛█
▝▜██████▀
 ▝▝   ▝▝
```

- Each line of the file is rendered as one line of the mascot, as is. Trailing blank lines are trimmed.
- **Header (optional)**: `key: value` lines above a `---` line form a header. Only `color` is supported for now.
  If any line above `---` is not `key: value` or blank, there is no header and the whole file is treated as art (so art containing a `---` row is safe).
- **Color from the skin**: Instead of the file header, you can set the mascot color with `colors.banner_accent` in the active skin's `~/.hermes/skins/<skin>.yaml`.
  The bundled [skins/custom.yaml](skins/custom.yaml) sets it to `#cc6b4e`. Edit this value to change the color without a header in `ascii_chara.txt`.

  ```yaml
  colors:
    banner_accent: "#cc6b4e"
  ```
- **Color precedence**: header `color` in `ascii_chara.txt` → the active skin's `colors.banner_accent` → default `#d77757`.
- If the file is missing, unreadable, or contains only a header with no art, the built-in art is used.
- The file is read once on startup, so restart `hermes --tui` after editing it.
