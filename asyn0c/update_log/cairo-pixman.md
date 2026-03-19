# cairo + pixman update log

Date: 2026-03-19

## Requested objective
Upgrade vendored cairo/pixman submodules to newer stable, CMake-enabled branches.

## Starting point
- cairo: `d4724ee921c4fa399ccbd0019c3d6917452e0ffd` (`origin/1.15.2+cmake`)
- pixman: `978475cf9ee793d817ba93b40069fa2a20abf85e` (`fix-mingw64-sqrtf` on top of `origin/0.34+cmake`)

## Actions performed
1. Queried SolveSpace fork refs and selected maintained stable CMake branches:
   - cairo: `origin/1.18.4+cmake`
   - pixman: `origin/0.46.4+cmake`
2. Updated submodules to:
   - cairo `e4cd47fcde357b50a99064d3a65dcf41a0b4dd02`
   - pixman `6564d88d8b872514f8bb7692337b5b1f96d18e98`
3. Rebuilt cross-Windows tree (`ToolTime_win`) with `Toolchain-mingw64.cmake`.
4. Resolved one compatibility issue exposed by newer cairo:
   - Link error in testsuite: undefined `__imp_cairo_debug_reset_static_data`
   - Cause: optional cairo debug cleanup symbol is not exported in this Windows/new-cairo combination.
   - Fix: guard the cleanup call in `test/harness.cpp` behind `#if !defined(_WIN32)`.

## Validation result
- Cross-Windows build completed successfully to 100% after the guard.
- Targets built include:
  - `solvespace.exe`
  - `solvespace-cli.exe`
  - `solvespace-testsuite.exe`
  - `solvespace-debugtool.exe`
  - `solvespace-benchmark.exe`
  - `CDemo.exe`

## Current state
- Parent repo now points to upgraded submodule revisions:
  - `extlib/cairo` → `e4cd47f...`
  - `extlib/pixman` → `6564d88...`
- Test harness includes a Windows-only guard for optional cairo static-data reset cleanup.
