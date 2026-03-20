# The Science of Cross Compilation from Ubuntu to Darwin

Date: 2026-03-20

## Purpose

This document records the practical, reproducible method used to cross-compile macOS targets from a Linux (Ubuntu/Mint) host for the ToolTime project, including host-to-host SDK transfer, toolchain bootstrapping, and pitfalls discovered during setup.

---

## 1) Host Topology Used

- **Linux build host (targeting macOS):** `node68.z.asyn0c.net`
- **macOS SDK source host:** `littlepaul.z.asyn0c.net` (`LittlePaul.local`)
- **Project repo:** `/dome/cccc/big_software/ToolTime`

Important: always verify current shell location before installing packages or copying files:

```sh
hostname -f
uname -a
whoami
```

---

## 2) macOS SDK Source Confirmation

On LittlePaul, available SDKs were confirmed under Command Line Tools:

- `/Library/Developer/CommandLineTools/SDKs/MacOSX15.2.sdk`
- `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk`
- `/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk`

Chosen SDK for Linux cross build:

- `MacOSX15.5.sdk`

---

## 3) Where SDK Lives on Linux

Installed on node68 at:

- `/opt/osxcross/target/SDK/MacOSX15.5.sdk`

Observed size after copy:

- ~`731M`

---

## 4) Reliable Transfer Method (with explicit SSH user)

To avoid auth ambiguity when using sudo/rsync+ssh, use explicit remote username:

```sh
rsync -a --partial --progress \
  -e 'ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 -o ServerAliveCountMax=20' \
  cccc@littlepaul.z.asyn0c.net:/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk \
  /opt/osxcross/target/SDK/
```

### Learned behavior

- `sudo rsync ...` can change SSH trust context (root known_hosts), causing host-key prompts in root context.
- Best pattern: make destination writable by `cccc`, then run rsync as `cccc`.
- Always specify `cccc@host` explicitly for SSH-like tools.

---

## 5) Linux Dependencies Required

Installed package set (Ubuntu/Mint family):

```sh
sudo apt-get update
sudo apt-get install -y \
  build-essential clang lld llvm cmake ninja-build git make patch \
  python3 pkg-config \
  libssl-dev libxml2-dev libzstd-dev xz-utils zlib1g-dev libbz2-dev \
  liblzma-dev libncurses-dev
```

Notes:

- `libtinfo-dev` may resolve via `libncurses-dev` depending on distro release.
- A non-critical external repo signature warning was observed for Warp; main Ubuntu/Mint repos still updated and installed successfully.

---

## 6) osxcross Installation & Build

Source location:

- `/opt/osxcross/src`

Clone:

```sh
git clone https://github.com/tpoechtrager/osxcross.git /opt/osxcross/src
```

Prepare SDK tarball (osxcross expects SDK tarballs in `tarballs/`):

```sh
mkdir -p /opt/osxcross/src/tarballs
tar -C /opt/osxcross/target/SDK -cJf /opt/osxcross/src/tarballs/MacOSX15.5.sdk.tar.xz MacOSX15.5.sdk
```

Build:

```sh
cd /opt/osxcross/src
UNATTENDED=1 TARGET_DIR=/opt/osxcross/target ./build.sh
```

Result:

- Working wrappers and cctools emitted into `/opt/osxcross/target/bin`
- Generated target triple family included `*-apple-darwin24.5-*`

Sanity checks used:

```sh
/opt/osxcross/target/bin/x86_64-apple-darwin24.5-clang --version
/opt/osxcross/target/bin/aarch64-apple-darwin24.5-clang --version
```

---

## 7) ToolTime Cross Script Added/Updated

Script:

- `asyn0c/,test,tooltime,x,ubuntu,mac`

Behavior implemented:

- Linux -> macOS cross build via osxcross
- Build directory fixed to: `ToolTine_mac` (as requested)
- Defaults to Darwin `24.5` to match built wrappers
- Supports:
  - `MAC_ARCH=x86_64|arm64`
  - `DARWIN_VERSION` override (or legacy `DARWIN_MAJOR` fallback)
  - `MACOSX_DEPLOYMENT_TARGET`
  - `OSXCROSS_ROOT`
  - `OSX_SDK_PATH`

Safety guard implemented:

- Refuses SDK path if it resolves inside the git repository tree.

Why this matters:

- Prevents accidental SDK ingestion into version control if ignore rules are changed or bypassed.

---

## 8) Git Safety Rules Added

In `.gitignore`, defensive entries were added:

- `/sdk*/`
- `/osxcross*/`
- `/*.sdk`

This complements the runtime script guard.

---

## 9) Practical Environment Exports

Recommended on node68 before running the cross script:

```sh
export OSXCROSS_ROOT=/opt/osxcross
export DARWIN_VERSION=24.5
# optional per build
# export MAC_ARCH=x86_64
# export MAC_ARCH=arm64
# export MACOSX_DEPLOYMENT_TARGET=12.0
```

---

## 10) Legal / Policy Boundary

Use only SDKs obtained through your own legitimate Apple/Xcode/CLT installation path and account rights.

---

## 11) Pitfalls and Corrections Observed

1. **Host confusion:** terminal context drifted between LittlePaul and node68; corrected by explicit host checks.
2. **SSH auth prompts with sudo:** root-context SSH host trust caused interruption; corrected by running rsync as `cccc` with explicit remote username.
3. **rsync option mismatch:** some environments rejected `--info=progress2`; `--progress` was compatible.
4. **Triple mismatch risk:** script originally defaulted to Darwin `24`; changed to `24.5` to match installed wrappers.

---

## 12) Current Known-Good State

- SDK present at `/opt/osxcross/target/SDK/MacOSX15.5.sdk`
- osxcross toolchain built and functioning
- ToolTime cross script present and syntax-validated
- defensive ignore + runtime guard in place

This is now a repeatable baseline for Ubuntu/Mint -> Darwin cross compilation in this workspace.
