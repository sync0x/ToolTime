#!/usr/bin/env bash
set -euo pipefail

# ToolTime MSYS2 provisioning script
#
# Recommended usage (run in MSYS shell):
#   bash asyn0c/provision-msys2-tooltime.sh
#
# Defaults:
#   - ucrt64 toolchain (modern 64-bit Windows target)
#   - mingw32 toolchain (32-bit target for SpaceMouse/SolveSpace integration needs)
#
# Standard out-of-source build directories:
#   - ToolTime_win_ucrt64
#   - ToolTime_win_ming32
#
# Optional targets:
#   --targets ucrt64,mingw32,mingw64,clang64
#
# After provisioning, open target shells with:
#   C:/cygsys64/msys2_shell.cmd -defterm -no-start -ucrt64  -here
#   C:/cygsys64/msys2_shell.cmd -defterm -no-start -mingw32 -here
#   C:/cygsys64/msys2_shell.cmd -defterm -no-start -mingw64 -here
#   C:/cygsys64/msys2_shell.cmd -defterm -no-start -clang64 -here
#
# Recommended build practice learned from the ToolTime experiments:
#   - always configure from the MSYS layer, not from Cygwin paths
#   - keep source and build trees separate
#   - for link-debugging, prefer a fresh build tree because MinGW/CMake link
#     graph changes are often easiest to verify only after full reconfigure
#   - on this host, use clean environment launches when automating remotely,
#     e.g.:
#       env -i HOME=/home/<user> PATH=/usr/bin:/bin \
#         MSYSTEM=MINGW32 CHERE_INVOKING=1 \
#         /c/cygsys64/usr/bin/bash.exe -lc \
#         'export PATH=/mingw32/bin:/usr/bin:/bin; cmake -S . -B ToolTime_win_ming32 -G Ninja ...'
#       env -i HOME=/home/<user> PATH=/usr/bin:/bin \
#         MSYSTEM=UCRT64 CHERE_INVOKING=1 \
#         /c/cygsys64/usr/bin/bash.exe -lc \
#         'export PATH=/ucrt64/bin:/usr/bin:/bin; cmake -S . -B ToolTime_win_ucrt64 -G Ninja ...'

SCRIPT_NAME="$(basename "$0")"
DEFAULT_TARGETS="ucrt64,mingw32"
TARGETS_CSV="$DEFAULT_TARGETS"
NO_UPGRADE=0
UPDATE_ONLY=0

usage() {
  cat <<EOF
$SCRIPT_NAME - provision MSYS2 toolchains for ToolTime

Options:
  --targets LIST       Comma-separated target list.
                       Supported: ucrt64, mingw32, mingw64, clang64
                       Default: $DEFAULT_TARGETS

  --no-upgrade         Skip system/package upgrade phase.
  --update-only        Only perform package database/system upgrade.
  -h, --help           Show this help.

Examples:
  $SCRIPT_NAME
  $SCRIPT_NAME --targets ucrt64,mingw32
  $SCRIPT_NAME --targets ucrt64,mingw32,clang64
  $SCRIPT_NAME --update-only

Recommended build directory names:
  ucrt64  -> ToolTime_win_ucrt64
  mingw32 -> ToolTime_win_ming32

Recommended remote automation pattern:
  - start from MSYS using env -i plus explicit MSYSTEM/PATH
  - configure into a fresh out-of-source directory when validating link fixes
EOF
}

log() {
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "$s"
}

split_csv_to_array() {
  local csv="$1"
  local -n out_ref="$2"
  out_ref=()

  IFS=',' read -r -a raw <<< "$csv"
  for item in "${raw[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    out_ref+=("$item")
  done
}

validate_target() {
  case "$1" in
    ucrt64|mingw32|mingw64|clang64) return 0 ;;
    *) return 1 ;;
  esac
}

install_pkg_group() {
  local desc="$1"; shift
  local pkgs=("$@")
  [[ ${#pkgs[@]} -eq 0 ]] && return 0

  log "Installing: $desc"
  pacman -S --noconfirm --needed "${pkgs[@]}"
}

upgrade_system() {
  log "Refreshing package database"
  pacman -Sy --noconfirm

  log "Upgrading MSYS2 system and packages (first pass)"
  pacman -Syu --noconfirm || true

  # Second pass is recommended by MSYS2; if first pass upgraded runtime,
  # a shell restart may be required. We still attempt the second pass.
  log "Upgrading MSYS2 system and packages (second pass)"
  pacman -Syu --noconfirm || true
}

packages_for_target() {
  local target="$1"
  case "$target" in
    ucrt64)
      cat <<'EOF'
mingw-w64-ucrt-x86_64-gcc
mingw-w64-ucrt-x86_64-cmake
mingw-w64-ucrt-x86_64-ninja
mingw-w64-ucrt-x86_64-make
mingw-w64-ucrt-x86_64-pkgconf
mingw-w64-ucrt-x86_64-python
mingw-w64-ucrt-x86_64-ccache
mingw-w64-ucrt-x86_64-gdb
EOF
      ;;
    mingw32)
      cat <<'EOF'
mingw-w64-i686-gcc
mingw-w64-i686-cmake
mingw-w64-i686-ninja
mingw-w64-i686-make
mingw-w64-i686-pkgconf
mingw-w64-i686-python
mingw-w64-i686-ccache
mingw-w64-i686-gdb
EOF
      ;;
    mingw64)
      cat <<'EOF'
mingw-w64-x86_64-gcc
mingw-w64-x86_64-cmake
mingw-w64-x86_64-ninja
mingw-w64-x86_64-make
mingw-w64-x86_64-pkgconf
mingw-w64-x86_64-python
mingw-w64-x86_64-ccache
mingw-w64-x86_64-gdb
EOF
      ;;
    clang64)
      cat <<'EOF'
mingw-w64-clang-x86_64-clang
mingw-w64-clang-x86_64-cmake
mingw-w64-clang-x86_64-ninja
mingw-w64-clang-x86_64-make
mingw-w64-clang-x86_64-pkgconf
mingw-w64-clang-x86_64-python
mingw-w64-clang-x86_64-ccache
mingw-w64-clang-x86_64-gdb
mingw-w64-clang-x86_64-lld
EOF
      ;;
    *)
      die "Internal error: unsupported target '$target'"
      ;;
  esac
}

build_dir_for_target() {
  case "$1" in
    ucrt64) printf '%s' 'ToolTime_win_ucrt64' ;;
    mingw32) printf '%s' 'ToolTime_win_ming32' ;;
    mingw64) printf '%s' 'ToolTime_win_mingw64' ;;
    clang64) printf '%s' 'ToolTime_win_clang64' ;;
    *) printf '%s' 'ToolTime_win_unknown' ;;
  esac
}

show_build_recipes() {
  local -a selected_targets=("$@")

  echo
  echo "Suggested out-of-source build directories and launch environment:"
  for t in "${selected_targets[@]}"; do
    case "$t" in
      ucrt64)
        echo "  [ucrt64]  build dir: $(build_dir_for_target "$t")"
        echo "            shell: MSYSTEM=UCRT64, PATH=/ucrt64/bin:/usr/bin:/bin"
        ;;
      mingw32)
        echo "  [mingw32] build dir: $(build_dir_for_target "$t")"
        echo "            shell: MSYSTEM=MINGW32, PATH=/mingw32/bin:/usr/bin:/bin"
        ;;
      mingw64)
        echo "  [mingw64] build dir: $(build_dir_for_target "$t")"
        echo "            shell: MSYSTEM=MINGW64, PATH=/mingw64/bin:/usr/bin:/bin"
        ;;
      clang64)
        echo "  [clang64] build dir: $(build_dir_for_target "$t")"
        echo "            shell: MSYSTEM=CLANG64, PATH=/clang64/bin:/usr/bin:/bin"
        ;;
    esac
  done

  echo
  echo "Recommended configure/build habits:"
  echo "  - prefer Ninja generators for reproducible logs and fast restart"
  echo "  - use a fresh build directory after link-graph changes"
  echo "  - inspect runtime DLL dependencies after a successful link"
  echo "  - keep required MinGW runtime DLLs next to the final .exe when testing on Windows"
}

show_summary() {
  local -a selected_targets=("$@")

  log "Provisioning summary"
  echo "Targets provisioned: ${selected_targets[*]}"

  echo
  echo "Suggested target shells:"
  for t in "${selected_targets[@]}"; do
    echo "  C:/cygsys64/msys2_shell.cmd -defterm -no-start -${t} -here"
  done

  echo
  echo "Toolchain quick checks:"
  for t in "${selected_targets[@]}"; do
    case "$t" in
      ucrt64)
        echo "  [ucrt64]  /c/cygsys64/ucrt64/bin/gcc.exe --version"
        ;;
      mingw32)
        echo "  [mingw32] /c/cygsys64/mingw32/bin/gcc.exe --version"
        ;;
      mingw64)
        echo "  [mingw64] /c/cygsys64/mingw64/bin/gcc.exe --version"
        ;;
      clang64)
        echo "  [clang64] /c/cygsys64/clang64/bin/clang.exe --version"
        ;;
    esac
  done

  show_build_recipes "${selected_targets[@]}"

  echo
  echo "Note: keeping mingw32 installed is intentional for 32-bit SolveSpace/SpaceMouse workflows."
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --targets)
        [[ $# -lt 2 ]] && die "--targets requires a value"
        TARGETS_CSV="$2"
        shift 2
        ;;
      --no-upgrade)
        NO_UPGRADE=1
        shift
        ;;
      --update-only)
        UPDATE_ONLY=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done

  require_cmd pacman

  # This script is designed to run from the MSYS layer; warn if not.
  if [[ "${MSYSTEM:-}" != "MSYS" ]]; then
    log "Warning: MSYSTEM='${MSYSTEM:-unset}'. Recommended to run from MSYS shell."
  fi

  local -a selected_targets=()
  split_csv_to_array "$TARGETS_CSV" selected_targets
  [[ ${#selected_targets[@]} -eq 0 ]] && die "No targets selected"

  local -A seen=()
  local -a dedup_targets=()
  for t in "${selected_targets[@]}"; do
    validate_target "$t" || die "Unsupported target '$t' (allowed: ucrt64, mingw32, mingw64, clang64)"
    [[ -n "${seen[$t]:-}" ]] && continue
    seen[$t]=1
    dedup_targets+=("$t")
  done
  selected_targets=("${dedup_targets[@]}")

  if [[ $NO_UPGRADE -eq 0 ]]; then
    upgrade_system
  else
    log "Skipping system upgrade (--no-upgrade)"
  fi

  if [[ $UPDATE_ONLY -eq 1 ]]; then
    show_summary
    exit 0
  fi

  # Base MSYS tools for scripting/automation.
  install_pkg_group \
    "MSYS base automation tools" \
    git openssh rsync unzip zip tar patch diffutils findutils grep sed gawk perl python make

  # Install each selected target toolchain.
  for target in "${selected_targets[@]}"; do
    mapfile -t target_pkgs < <(packages_for_target "$target")
    install_pkg_group "Target '$target' toolchain" "${target_pkgs[@]}"
  done

  show_summary "${selected_targets[@]}"
}

main "$@"
