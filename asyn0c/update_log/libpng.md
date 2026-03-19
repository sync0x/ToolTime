# libpng update log

Date: 2026-03-19

## Trigger
After bumping zlib to `v1.3.2`, Windows cross-build failed in libpng with:

- `#error ZLIB_VERNUM != PNG_ZLIB_VERNUM`
- File: `extlib/libpng/pngpriv.h`

## Diagnosis summary
- Build-time generated `pnglibconf.h` contained `PNG_ZLIB_VERNUM 0x1290`.
- New zlib submodule now reported `ZLIB_VERNUM` for 1.3.2.
- libpng intentionally aborts when these differ.

## Requested objective
Upgrade `extlib/libpng` to a stable release (not development/beta) to match modern zlib integration.

## Actions performed
1. Fetched libpng tags in submodule.
2. Filtered out beta series (`v1.7.0beta*`).
3. Selected latest stable 1.6.x tag: `v1.6.55`.
4. Checked out `extlib/libpng` to tag `v1.6.55` (`c3e304954`).
5. Reconfigured Windows cross-build tree (`ToolTime_win`).
6. Rebuilt with parallel make.

## Build observations of interest
- CMake detected:
  - in-tree zlib version `1.3.2`
  - in-tree libpng version `1.6.55`
- libpng regenerated config artifacts (`pnglibconf.c`, `pnglibconf.h`, `pngprefix.h`, etc.).
- Previous zlib-version mismatch error disappeared.
- Full Windows cross-build completed successfully through:
  - `solvespace.exe`
  - `solvespace-cli.exe`
  - `solvespace-testsuite.exe`
  - `solvespace-debugtool.exe`
  - `solvespace-benchmark.exe`
  - `CDemo.exe`

## Current state
- `extlib/libpng` submodule is now at:
  - tag: `v1.6.55`
  - commit: `c3e304954a9cfd154bc0dfbfea2b01cd61d6546d`
- Parent repository sees a submodule pointer update for `extlib/libpng`.

## Compatibility status
- zlib `v1.3.2` + libpng `v1.6.55`: validated by successful Windows cross-build in this workspace.
