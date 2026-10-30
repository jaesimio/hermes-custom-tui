[English](README.md) | **한국어**

# hermes-custom-tui

Hermes TUI(`ui-tui`)에 커스텀 스타일 UI를 입힌 버전입니다.
`install.sh`로 설치된 Hermes의 `ui-tui`를 이 저장소의 소스로 바꾸고 `custom` 테마([skins/custom.yaml](skins/custom.yaml))를 적용하며,
`uninstall.sh`로 원래 상태로 되돌립니다.

경로는 모두 `$HERMES_HOME` 기준이며, 설정되지 않았으면 `~/.hermes`를 사용합니다.

원본 Hermes TUI 문서는 [README_ORI.md](README_ORI.md)를 참고하세요.

## 사전 요구사항

- Hermes가 `~/.hermes/hermes-agent`에 설치되어 있어야 합니다. 빌드 스크립트 `~/.hermes/hermes-agent/scripts/build/tui.mjs`를 사용합니다.
- `~/.hermes/hermes-agent/ui-tui/node_modules`가 이미 설치되어 있어야 합니다. 스크립트는 `npm install`을 실행하지 않습니다.
- `node`, `rsync`, `tar`
- 테마 적용에 `hermes` 명령을 사용합니다. PATH에 없으면 테마 파일만 복사하고 경고를 출력합니다.

## 설치 — `install.sh`

```bash
./install.sh
```

동작 순서:

1. **백업**: `~/.hermes/hermes-agent/ui-tui`가 있으면 `node_modules`, `dist`를 제외하고
   `~/.hermes/backups/ui-tui-pre-custom-<YYYYMMDD_HHMMSS>.tar.gz`로 압축합니다.
   이 경로는 `~/.hermes/backups/latest_ui_tui_backup.txt`에 기록됩니다.
   백업 시점의 hermes 버전(`hermes --version` 첫 줄)은 `ui-tui-pre-custom-<TS>.version`에 함께 저장됩니다.
2. **테마 상태 백업**: 같은 타임스탬프로 다음 파일을 저장합니다.
   - `skin-pre-custom-<TS>.env`: 이전 활성 테마(`display.skin`)와 기존 테마 파일 존재 여부
   - `skin-pre-custom-<TS>.yaml`: 기존 `~/.hermes/skins/custom.yaml` (있었던 경우에만)
3. **동기화**: 이 저장소의 파일을 `rsync --delete`로 `~/.hermes/hermes-agent/ui-tui`에 복사합니다.
   `.git`, `node_modules`, `dist`, `skins`는 제외되며, 대상에만 있는 나머지 파일은 삭제됩니다.
4. **테마 설치/적용**: `skins/custom.yaml`을 `~/.hermes/skins/`에 복사하고 `hermes skin use custom`로 적용합니다.
5. **빌드**: 대상 디렉터리에서 `node ../scripts/build/tui.mjs`를 실행합니다.

설치 후 평소처럼 `hermes --tui`로 실행합니다.

> **주의**: `install.sh`는 실행할 때마다 현재 `ui-tui`를 새로 백업하고 `latest_ui_tui_backup.txt`를 덮어씁니다.
> 이미 설치된 상태에서 다시 실행하면 최신 백업은 **원본이 아닌 이전 hermes-custom-tui 버전**이 됩니다.
> 원본으로 되돌리려면 `uninstall.sh` 실행 시 가장 오래된 백업을 선택하세요.

## 배경색

배경색은 코드가 아닌 테마에서 지정합니다. 활성 테마 파일 `~/.hermes/skins/<테마>.yaml`의 `colors.background`를 설정하세요
(기본 테마는 [skins/custom.yaml](skins/custom.yaml)이며, 기본값은 주석 처리되어 있습니다).

```yaml
colors:
  background: "#18181b"
```

- 설정하면 TUI가 터미널 배경을 이 색으로 칠하고(OSC 11), 패널/상태 표시줄 배경도 이 색을 기준으로 만듭니다.
  라이트/다크 모드도 터미널 감지 대신 이 색으로 판단합니다.
- 설정하지 않으면 터미널 자체 배경을 그대로 사용합니다(투명 터미널에 적합).
- 변경 후에는 `hermes --tui`를 다시 실행하세요.
- `install.sh`는 `~/.hermes/skins/custom.yaml`을 저장소의 파일로 덮어쓰므로, 계속 유지할 변경은 이 저장소의 `skins/custom.yaml`에서 하세요.

## 제거 — `uninstall.sh`

```bash
./uninstall.sh
```

동작 순서:

1. **백업 선택**: `~/.hermes/backups/ui-tui-*.tar.gz`를 최신순으로 보여주고 번호로 선택합니다.
   - 백업이 1개뿐이면 선택 없이 바로 진행합니다.
   - Enter만 누르면 기본값을 사용합니다. 기본값은 `latest_ui_tui_backup.txt`가 가리키는 백업(마지막 `install.sh` 직전 상태)이고, 없으면 가장 최근 백업입니다.
   - 백업이 하나도 없으면 에러로 종료합니다.

   ```text
   [uninstall.sh] Select a backup to restore (newest first):
      1) ui-tui-pre-custom-20261029_170105.tar.gz  (default)
      2) ui-tui-pre-custom-20261029_154526.tar.gz
   Enter number [default: 1]:
   ```
2. **hermes 버전 확인**: 백업의 `.version`에 기록된 hermes 버전이 현재 버전과 다르면 경고하고 `y/N`으로 진행 여부를 묻습니다.
   (`install.sh` → `hermes update` → `uninstall.sh` 순서로 실행했을 때 이전 버전의 ui-tui로 덮어쓰는 충돌을 막기 위함)
   - `y`를 입력해야 복원을 진행하고, Enter나 다른 입력은 복원하지 않고 종료합니다.
   - `.version` 파일이 없는 백업(이 기능 이전에 만든 백업 등)은 버전 확인을 건너뜁니다.

   ```text
   [uninstall.sh] Warning: the hermes version differs from when the backup was made.
     At backup: Hermes Agent v0.21.5+9141.ga28a5d0 (2026.9.24) · upstream a28a5d03
     Current:   Hermes Agent v0.21.6+9210.g1b2c3d4 (2026.10.28) · upstream 1b2c3d4e
     Restoring will overwrite ui-tui with an older version that may not match the current hermes, and the build or runtime may fail.
   Restore anyway? [y/N]:
   ```
3. **ui-tui 복원**: 선택한 백업을 `~/.hermes/hermes-agent/`에 압축 해제해 `ui-tui`를 덮어씁니다.
   압축 해제는 파일을 덮어쓰기만 하므로, hermes-custom-tui에서 새로 추가된 파일은 남아 있을 수 있습니다.
   빌드는 `src/entry.tsx`에서 import되는 파일만 번들링하므로, 남은 파일은 빌드에 영향을 주지 않습니다.
4. **테마 복원**: 선택한 백업과 같은 타임스탬프의 테마 상태가 있으면 되돌립니다.
   - 설치 전에 `custom.yaml`이 있었으면 백업본으로 복원하고, 없었으면 삭제합니다.
   - `hermes skin use <이전 테마>`로 이전 활성 테마를 다시 적용합니다.
   - 테마 상태가 없는 백업(이 기능 이전에 만든 백업 등)은 테마 복원을 건너뜁니다.
   - 테마 이름이 `custom`으로 바뀌기 전의 `ui-tui-pre-claude-*` 백업도 지원하며, 이 경우 `claude-code.yaml`을 복원합니다.
5. **빌드**: `node ../scripts/build/tui.mjs`로 `ui-tui/dist/entry.js`를 자동으로 다시 빌드합니다.
   빌드가 실패하면 스크립트도 실패 코드로 종료합니다.

> 원본으로 되돌리려면 목록에서 가장 오래된 `ui-tui-pre-custom-*` 백업(맨 아래)을 선택하세요.

## 마스코트 변경 — `skins/ascii_chara.txt`

시작 배너 왼쪽의 마스코트는 `~/.hermes/skins/ascii_chara.txt`로 원하는 ASCII 아트로 바꿀 수 있습니다.
이 파일은 저장소에 포함되어 있지 않으므로 직접 만들어야 합니다. `install.sh`와 `uninstall.sh`는 이 파일을 건드리지 않습니다.

```text
color: #d77757
---
 ▐▛███▛█
▝▜██████▀
 ▝▝   ▝▝
```

- 파일의 각 줄이 그대로 마스코트의 한 줄로 출력됩니다. 끝의 빈 줄은 제거됩니다.
- **헤더(선택)**: `---` 줄 위의 `key: value` 줄들이 헤더가 됩니다. 현재는 `color`만 지원합니다.
  `---` 위에 `key: value`나 빈 줄이 아닌 줄이 있으면 헤더로 보지 않고 파일 전체를 아트로 취급합니다(아트에 `---` 줄이 있어도 안전합니다).
- **테마에서 색상 지정**: 파일 헤더 대신 활성 테마 파일 `~/.hermes/skins/<테마>.yaml`의 `colors.banner_accent`로도 마스코트 색상을 지정할 수 있습니다.
  함께 제공되는 [skins/custom.yaml](skins/custom.yaml)은 `#cc6b4e`로 설정되어 있습니다. 이 값을 바꾸면 `ascii_chara.txt`에 헤더가 없어도 색상이 바뀝니다.

  ```yaml
  colors:
    banner_accent: "#cc6b4e"
  ```
- **색상 우선순위**: `ascii_chara.txt` 헤더의 `color` → 활성 테마의 `colors.banner_accent` → 기본값 `#d77757`.
- 파일이 없거나 읽을 수 없거나, 헤더만 있고 아트가 비어 있으면 내장 아트를 사용합니다.
- 파일은 시작 시 한 번만 읽으므로, 수정한 뒤에는 `hermes --tui`를 다시 실행하세요.
