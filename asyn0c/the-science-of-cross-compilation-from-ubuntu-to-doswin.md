# The Science of Cross-Compilation from Ubuntu to DOS/Win

## Remote Host Inventory: `sync0x@LittleJohn.z.asyn0c.net`

The host currently contains two distinct Unix-like Windows environments:

- `/c/cygwin64` — a full Cygwin installation
- `/c/cygsys64` — an MSYS2-style installation under the local `cygsys` naming convention

The findings below began with direct inspection on 21 March 2026 and were extended through real provisioning and build-debug work on 22 March 2026.

## Final Naming Convention for Windows Build Trees

For ToolTime, the standardized out-of-source Windows build directories are now:

- `ToolTime_win_ucrt64` — the Universal CRT 64-bit build tree
- `ToolTime_win_ming32` — the 32-bit MinGW build tree

These names should be used consistently in documentation, automation, and remote shell commands.

The naming rationale is deliberate:

- `win` already establishes the platform as Windows
- `ucrt64` is the precise ABI/runtime/toolchain family
- `ming32` is the concise 32-bit MinGW contraction, with no realistic ambiguity in this context
- the two preferred suffixes are visually balanced and easy to scan in logs

## Update After Real MSYS2 Provisioning and Build Work

The host is no longer merely an inspected target. It has now been used for actual ToolTime provisioning and native Windows builds.

The final practical state is:

- `/c/cygsys64/ucrt64` is provisioned and usable for native 64-bit UCRT builds
- `/c/cygsys64/mingw32` is provisioned and usable for native 32-bit Windows builds
- MSYS itself remains the orchestration layer for package installs, repository operations, and scripted entry into target shells
- the 32-bit ToolTime experiment reached a runnable PE32 GUI executable with runtime DLL staging beside the executable
- several link problems could only be verified by deleting the build tree and reconfiguring from scratch

### `/c/cygwin64` availability

Detected layout:

- `bin/`
- `usr/bin/`
- `etc/`
- `etc/setup/`

Detected tools in-place:

- `bash`
- `sh`
- `gcc`
- `g++`
- `clang`
- `clang++`
- `cmake`
- `make`
- `pkg-config`
- `python3`
- `perl`
- `git`
- `apt-cyg`
- `mintty`
- `cygpath`

Selected installed packages found in `etc/setup/installed.db`:

- `clang`
- `cmake`
- `gcc-core`
- `gcc-g++`
- `git`
- `make`
- `perl`
- `pkg-config`
- `python3`

Observed versions:

- `gcc`: `13.4.0`
- `g++`: `13.4.0`
- `clang++`: `20.1.8`
- `cmake`: `4.2.1`
- `make`: `4.4.1`
- `git`: `2.51.0`
- `bash`: `5.2.21`

Also present:

- `apt-cyg`
- `etc/setup/setup.rc`
- `etc/setup/installed.db`

Not observed at the root during this pass:

- `setup-x86_64.exe`
- `ninja`

### `/c/cygsys64` availability

Detected layout:

- `usr/`
- `usr/bin/`
- `mingw64/`
- `ucrt64/`
- `clang64/`
- `clangarm64/`
- `mingw32/`

Detected base tools in `usr/bin`:

- `bash`
- `sh`
- `perl`
- `git`
- `pacman`
- `mintty`
- `cygpath`

Detected launcher/front-end executables:

- `msys2.exe`
- `msys2_shell.cmd`
- `mingw32.exe`
- `mingw64.exe`
- `ucrt64.exe`
- `clang64.exe`
- `clangarm64.exe`
- `autorebase.bat`

Toolchain state by target prefix:

- `mingw64/`: directory exists, but no compiler/build tools were found in `mingw64/bin` during this pass
- `ucrt64/`: provisioned and compiler/build tools confirmed
	- `gcc`
	- `g++`
	- `cmake`
	- `ninja`
	- `make`
- `clang64/`: directory exists, but no compiler/build tools were found in `clang64/bin` during this pass
- `clangarm64/`: directory exists, but no compiler/build tools were found in `clangarm64/bin` during this pass
- `mingw32/`: provisioned and compiler/build tools confirmed
	- `gcc`
	- `g++`
	- `cmake`
	- `ninja`
	- `make`

Selected installed packages reported by `pacman -Q`:

- `msys2-runtime 3.6.7-2`
- `pacman 6.1.0-22`
- `bash 5.3.009-1`
- `git 2.53.0-1`
- `mingw-w64-ucrt-x86_64-binutils 2.46-2`
- `mingw-w64-ucrt-x86_64-crt 13.0.0...`
- `mingw-w64-ucrt-x86_64-gcc 15.2.0-13`
- `mingw-w64-ucrt-x86_64-gcc-libs 15.2.0-13`
- `mingw-w64-ucrt-x86_64-headers 13.0.0...`
- supporting `gmp`, `isl`, `mpc`, `mpfr`, `zlib`, `zstd`, `winpthread` packages

Not observed in the currently installed package set during the initial inspection pass:

- any populated `mingw64` toolchain
- any populated `clang64` toolchain

Subsequent provisioning added at least the following practical build stack for the targets actually used:

- MSYS base automation tools: `git`, `openssh`, `rsync`, `zip`, `unzip`, `tar`, `patch`, `diffutils`, `findutils`, `grep`, `sed`, `gawk`, `perl`, `python`, `make`
- `ucrt64`: `gcc`, `cmake`, `ninja`, `make`, `pkgconf`, `python`, `ccache`, `gdb`
- `mingw32`: `gcc`, `cmake`, `ninja`, `make`, `pkgconf`, `python`, `ccache`, `gdb`

## What This Means in Practice

### Cygwin is the broader POSIX environment

The full Cygwin tree is better when the build assumes a real Unix userspace rather than merely a native Windows compiler:

- richer POSIX shell and utility coverage
- more direct compatibility with `./configure`, Autotools, shell-heavy bootstrap scripts, and mixed Python/Perl/sed/awk glue
- more likely to run upstream Unix build instructions with minimal patching
- easier to preserve Linux-like scripts verbatim, especially if they expect Cygwin paths and Cygwin DLL semantics

In short: if the problem is “make Windows behave more like a Unix build machine”, full Cygwin is usually the stronger answer.

### `cygsys` / MSYS2 is the cleaner native-Windows packaging story

The `cygsys` tree is much leaner, but it is already structured the way modern Windows-native open-source development normally wants:

- one small MSYS runtime for shells and package management
- separate target prefixes for the actual native toolchains
- `pacman` available immediately for unattended installs and upgrades
- ready-made launchers for each target environment

That makes it more attractive when the goal is not “Unix emulation” but “native Windows executables built from a scripted Unix-ish shell”.

## Why Full Cygwin Still Has an Advantage over Minimalist `cygsys`

The main advantage of full Cygwin is completeness.

- It already contains a coherent POSIX userland plus compiler stack.
- It is better suited to build systems that expect many helper programs beyond the compiler itself.
- It is friendlier to legacy scripts that assume `/usr/bin`, `bash`, `make`, `python3`, `perl`, and GNU userland all coexist in one environment.
- It reduces the chance of discovering that a seemingly small script dependency is missing from a target prefix.

This matters for ToolTime-like automation, because build orchestration often depends on much more than `gcc` and `cmake`.

## Why MSYS2 Has an Automation Advantage over Cygwin

Even though Cygwin is fuller, MSYS2 is easier to automate from scratch.

### MSYS2 automation advantages

- `pacman` is built in and first-class.
- Package install commands are deterministic and scriptable out of the box.
- No extra bootstrap step is needed to obtain the package manager itself.
- Targeted installs are cleanly namespaced by prefix, e.g. `mingw-w64-ucrt-x86_64-*`.
- Upgrades and environment provisioning are easier to express in CI or provisioning scripts.

### Cygwin automation drawbacks

- The stock package manager flow normally revolves around `setup-x86_64.exe`, which is awkward for unattended shell-driven provisioning.
- On this host, `apt-cyg` is present and useful, but it is still an add-on, not the canonical base installer.
- That means a scripted build target either:
	- depends on `apt-cyg` already having been installed, or
	- must bootstrap `apt-cyg` first, or
	- must drive the GUI/CLI installer executable in a less pleasant way.

So the contrast is:

- **Cygwin**: better Unix compatibility
- **MSYS2**: better scripted provisioning and repeatable package installs

## Appropriate `cygsys` Targets to Use

If we opt for the `cygsys` / MSYS2 model, the target shell matters.

### `msys2` regular shell

Use this for:

- package management
- repository operations
- shell scripting
- orchestration and helper scripts

Do **not** treat the plain MSYS shell as the primary target for release binaries. It is the maintenance shell, not the ideal native-app ABI target.

### `ucrt64`

This is the most appropriate default for modern 64-bit Windows 11 development.

Use it for:

- native 64-bit application builds
- current GCC-based Windows targets
- modern CRT behavior aligned with UCRT
- general-purpose automated builds for contemporary Windows systems

After provisioning, `ucrt64` is the most mature default target prefix for ToolTime automation.

### `clang64`

Use this if the project specifically wants LLVM/Clang rather than GCC.

Good reasons:

- consistent Clang diagnostics across platforms
- LLVM tooling integration
- projects already validated under Clang on Linux/macOS

At present on this host, the `clang64` directory exists but is not provisioned with the compiler and build tools yet.

### `mingw64`

Use this for classic MinGW-w64 x86_64 builds when compatibility with established `mingw64` package naming or older Windows build recipes matters.

Good reasons:

- existing scripts assume `mingw64`
- package names or documentation already target `mingw-w64-x86_64-*`
- a project has been historically validated against that runtime choice

At present on this host, `mingw64` exists as a prefix but is not currently provisioned with the toolchain.

### `mingw32`

Use only when a true 32-bit Windows target is still required.

For new Windows 11 workstation provisioning, this is usually optional and can be skipped unless the product explicitly ships 32-bit artifacts.

For ToolTime specifically, `mingw32` proved valuable because:

- SpaceMouse integration work still made a real 32-bit path worth exploring
- it exposed library-linking and runtime-DLL details that are easy to miss when staying only in the 64-bit path
- the resulting command/environment discipline is reusable for other legacy or compatibility-sensitive Windows packages

### `clangarm64`

Use only if ARM64 Windows support is a real target. It is not a default choice for a general x86_64 Windows build farm.

## Recommended Direction If We Standardize on `cygsys`

If ToolTime were to standardize on the `cygsys` model, the recommended split would be:

- use **MSYS regular** for provisioning and orchestration
- use **`ucrt64`** as the default native build target
- optionally add **`clang64`** for LLVM validation builds
- add **`mingw64`** only if compatibility with older MinGW-based recipes is needed
- add **`mingw32`** only if 32-bit deliverables are still part of the release matrix

That gives a clean default while still allowing additional target prefixes for compatibility or testing.

## Canonical Build Tree Names and Shell Environments

The most useful convention coming out of the MSYS work is to make the target ABI obvious in both the directory name and the shell entry command.

### Canonical build trees

- `ToolTime_win_ucrt64`
- `ToolTime_win_ming32`

These are better than generic names like `build` or `build_mingw32` because they:

- survive log excerpts and copied command history with more context intact
- let multiple Windows target trees coexist without mental bookkeeping
- make it easier to compare 32-bit and 64-bit failures side by side
- generalize cleanly to other targets if needed later

### Canonical remote shell launch pattern

When launching remotely from Ubuntu into the MSYS2 installation on Windows, the most repeatable approach is a clean environment plus explicit `MSYSTEM` and `PATH`.

For `mingw32`:

```sh
env -i HOME=/home/<user> PATH=/usr/bin:/bin MSYSTEM=MINGW32 CHERE_INVOKING=1 \
	/c/cygsys64/usr/bin/bash.exe -lc \
	'export PATH=/mingw32/bin:/usr/bin:/bin; cd /home/<user>/ToolTime; cmake -S . -B ToolTime_win_ming32 -G Ninja ...'
```

For `ucrt64`:

```sh
env -i HOME=/home/<user> PATH=/usr/bin:/bin MSYSTEM=UCRT64 CHERE_INVOKING=1 \
	/c/cygsys64/usr/bin/bash.exe -lc \
	'export PATH=/ucrt64/bin:/usr/bin:/bin; cd /home/<user>/ToolTime; cmake -S . -B ToolTime_win_ucrt64 -G Ninja ...'
```

This is worth preserving because it removes ambiguity about:

- which shell layer is active
- which compiler family is first on `PATH`
- whether Cygwin or MSYS path translation is in play
- whether a previous interactive shell polluted the environment

## What We Learned Actually Building Under MSYS2

The most valuable knowledge from this exercise is not just which packages to install, but how to drive the environment when the build is almost right and only the final link or runtime validation remains.

### 1. Use MSYS as the control plane, not as the target ABI

The plain MSYS shell is the right place for:

- `pacman`
- shell scripts
- `rsync`
- remote orchestration
- wrapper commands that enter `ucrt64` or `mingw32`

The actual native build should happen with the matching target compiler prefix first on `PATH`.

### 2. Prefer explicit target-specific out-of-source directories

Use:

- `ToolTime_win_ucrt64`
- `ToolTime_win_ming32`

Avoid reusing one build directory for multiple target prefixes. That causes confusion in:

- CMake cache contents
- generated Ninja link lines
- transitive library resolution
- copied runtime DLL state

### 3. For link-debugging, deleting the build tree is often faster than incremental guesswork

This was one of the clearest lessons from the 32-bit experiment.

When diagnosing MinGW/CMake link issues, the only reliable proof that a fix worked was often:

1. delete the target build tree entirely
2. re-run `cmake -S . -B <tree> -G Ninja ...`
3. rebuild the target from zero
4. inspect the final Ninja link edge or the final linker invocation again

This matters because subtle target-interface and cache changes may not fully invalidate the generated link graph in a way that is easy to trust from partial rebuilds.

For future 32-bit Windows packages, budget for this. A clean rebuild is not wasted time if it answers the only question that matters: did the final link line change?

### 4. Inspect generated build files when the link line looks impossible

When a library token appears that “should not be there”, inspect the generated build graph directly.

Practical examples:

- search `build.ninja` for the offending token
- inspect the final executable link edge
- inspect library target link interfaces indirectly by seeing what propagated into Ninja

This is often faster than theorizing about CMake behavior in the abstract.

### 5. Runtime validation is a separate phase from link success

A successful Windows link is not the end of the experiment.

The 32-bit ToolTime build linked successfully and then immediately surfaced a runtime dependency issue:

- missing `libwinpthread-1.dll`

The practical fix was to stage the required MinGW runtime DLLs beside the executable in the build output directory.

That lesson generalizes well to other packages:

- always inspect imported DLLs for a produced `.exe`
- test-launch the executable on Windows as soon as it exists
- treat runtime DLL colocation as part of the build deliverable, not an afterthought

### 6. Keep compiler/linker warnings categorized by severity

During the 32-bit work, several warnings appeared repeatedly:

- ignored OpenMP pragmas because OpenMP was not enabled
- deprecated or questionable C++ patterns in upstream code
- `.drectve` warnings originating from the 32-bit SpaceWare import library

The right workflow was to separate them into:

- warnings that do not block the build
- warnings that indicate future cleanup candidates
- the single failure that currently blocks the artifact

This prevents distraction when the immediate goal is to prove a target ABI works at all.

### 7. Preserve exact successful command lines

For future work on a different package that must build under 32-bit Windows, keep the exact remote command patterns, including:

- `env -i`
- `HOME=/home/<user>`
- `PATH=/usr/bin:/bin`
- `MSYSTEM=<target>`
- `CHERE_INVOKING=1`
- the target-prefixed `PATH` export inside the shell
- a named out-of-source build tree

Those details save time because they eliminate the most common source of confusion: not the compiler itself, but the shell and path context around it.

## ToolTime-Specific 32-Bit Notes That Generalize Well

Even though these experiments were done for ToolTime, the workflow is broadly reusable for other software that still needs a 32-bit Windows target.

Useful general lessons:

- provision the target compiler family fully before debugging project code
- verify `gcc`, `cmake`, and `ninja` in the target prefix before the first project configure
- do not mix Cygwin paths into an MSYS-targeted build unless you have a very specific reason
- name build trees after the ABI target, not after whatever command happened to create them first
- if a link fix affects transitive libraries, expect to restart the build from scratch to verify it
- after link success, inspect runtime dependencies and stage DLLs early

## Recommended Baseline Commands

For future reference, the build skeletons should now look like this.

### 32-bit MinGW build

```sh
export PATH=/mingw32/bin:/usr/bin:/bin
cmake -S . -B ToolTime_win_ming32 -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DENABLE_TESTS=OFF \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
	-DZLIB_BUILD_SHARED=OFF \
	-DCMAKE_RC_FLAGS=--use-temp-file
cmake --build ToolTime_win_ming32 --target solvespace -j2
```

### 64-bit UCRT build

```sh
export PATH=/ucrt64/bin:/usr/bin:/bin
cmake -S . -B ToolTime_win_ucrt64 -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DENABLE_TESTS=OFF
cmake --build ToolTime_win_ucrt64 --target solvespace -j2
```

## Complete Preparation of a New Windows 11 Development Target

The sequence below assumes a brand new Windows 11 system that is being prepared to participate in automated ToolTime-style builds.

### 1. Base operating-system preparation

- install all pending Windows Updates
- give the machine a stable hostname
- create or confirm the dedicated build user account
- enable OpenSSH Server if remote administration will be used
- confirm inbound SSH access from the orchestration host
- confirm the build user can log in non-interactively as needed
- set the system clock and time sync correctly

### 2. Basic filesystem layout

Choose and standardize install roots, for example:

- `C:\cygwin64` for full Cygwin
- `C:\cygsys64` for MSYS2 under the local naming convention
- `C:\src` or another fixed path for working trees
- `C:\ccache` if compiler caching will be used

Create these paths deliberately so automation scripts never rely on ad-hoc per-user locations.

### 3. Decide between the two Unix layers

#### Option A: Full Cygwin

Install Cygwin if the target needs:

- the richest Unix compatibility
- shell-heavy upstream build flows
- Autotools/configure-style software
- one broad POSIX environment that can build and script in the same space

Install at minimum:

- `bash`
- `coreutils`
- `findutils`
- `grep`
- `sed`
- `gawk`
- `make`
- `cmake`
- `gcc-core`
- `gcc-g++`
- `clang` if desired
- `git`
- `python3`
- `perl`
- `pkg-config`
- `ninja` if the project uses Ninja
- any project-specific dev libraries

If unattended package installs are required later, also provision `apt-cyg` as part of the machine bootstrap and keep that step documented in the base image process.

#### Option B: `cygsys` / MSYS2

Install MSYS2 if the target needs:

- repeatable shell-scripted package installs
- native MinGW/UCRT/Clang Windows binaries
- cleaner CI/provisioning semantics
- separation between the maintenance shell and target ABI environments

After base install, immediately perform the normal MSYS2 update cycle from the MSYS shell:

- refresh package database
- upgrade core packages
- restart shell if required
- repeat until fully current

Then install the desired target packages.

For a modern default `ucrt64` host, provision at minimum:

- `mingw-w64-ucrt-x86_64-gcc`
- `mingw-w64-ucrt-x86_64-cmake`
- `mingw-w64-ucrt-x86_64-ninja`
- `mingw-w64-ucrt-x86_64-pkgconf`
- `mingw-w64-ucrt-x86_64-python`
- `mingw-w64-ucrt-x86_64-make` or `mingw-w64-ucrt-x86_64-ninja` depending on generator choice
- any required third-party libraries for the project

From the MSYS layer itself, also ensure:

- `git`
- `bash`
- `perl` if scripts use it

If Clang validation is desired, also provision the `clang64` package family.

### 4. Install auxiliary native Windows dependencies

Depending on the project, also install:

- Visual C++ redistributables if required by helper tools
- DirectX/OpenGL runtime support as needed
- printer/cutter vendor drivers if the workstation controls hardware
- signing tools if release artifacts must be signed on the Windows node
- 7-Zip or another archiver if packaging scripts require it

### 5. Configure remote automation

- verify `ssh user@host` works from the orchestrating Linux machine
- ensure PATH is stable in non-interactive remote shells
- document whether the remote login lands in Cygwin, MSYS2, PowerShell, or `cmd.exe`
- provide wrapper scripts for entering the right environment, e.g.:
	- Cygwin shell wrapper
	- `msys2_shell.cmd -defterm -no-start -ucrt64 -here`
- normalize line endings and locale expectations

This wrapper step is important. The orchestration host should not have to guess whether a command must run in Cygwin, MSYS, `ucrt64`, or native `cmd.exe`.

### 6. Install source and caches

- clone the repository to a fixed path
- configure any submodules or vendored dependencies
- define compiler cache location if used
- define build output directories separate from source
- ensure the build user owns and can clean these locations

### 7. Validate the toolchain end-to-end

For either Cygwin or `cygsys`, validate:

- `bash --version`
- `git --version`
- compiler version (`gcc --version` and/or `clang --version`)
- `cmake --version`
- `make --version` or `ninja --version`
- a minimal compile-and-link test
- a full project configure/build cycle
- any packaging/export step relevant to ToolTime

### 8. Freeze the provisioning recipe

Once the workstation is known-good:

- record the exact package list
- record the exact install roots
- record the chosen target prefix (`ucrt64`, `clang64`, etc.)
- keep the wrapper scripts in version control
- keep one bootstrap script that can recreate the machine with minimal manual work

That last step is what turns a one-off successful workstation into a repeatable build target.

## Recommended Baseline for a Fresh Windows 11 ToolTime Builder

If building a new Windows 11 target today, the most balanced default would be:

1. install OpenSSH Server
2. install `cygsys` / MSYS2 under `C:\cygsys64`
3. update MSYS2 fully with `pacman`
4. provision the `ucrt64` toolchain and build utilities
5. optionally install `clang64` for a second validation toolchain
6. add full Cygwin only if the build scripts prove they truly need deeper POSIX compatibility

This yields the easiest automation story first, while still leaving room to layer in Cygwin where the project benefits from it.

## Bottom Line

- `/c/cygwin64` remains the more complete Unix-like compatibility layer on `LittleJohn`.
- `/c/cygsys64` is now the more useful automation and native-build layer for ToolTime in practice, with both `ucrt64` and `mingw32` provisioned and exercised.
- If the priority is maximum Unix compatibility, favor **Cygwin**.
- If the priority is reproducible scripted provisioning and native Windows package namespaces, favor **MSYS2 / `cygsys`**.
- For ToolTime’s default modern Windows target, favor **`ucrt64`** with build tree **`ToolTime_win_ucrt64`**.
- For 32-bit compatibility work, use **`mingw32`** with build tree **`ToolTime_win_ming32`**, and expect clean rebuilds plus runtime DLL verification to be part of the normal workflow.
