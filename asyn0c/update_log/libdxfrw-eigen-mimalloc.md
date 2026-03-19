# libdxfrw + Eigen + mimalloc update log

Date: 2026-03-19

## Requested objective
Upgrade the remaining three vendored dependencies in one pass:
- `extlib/libdxfrw`
- `extlib/eigen`
- `extlib/mimalloc`

## Starting point
- libdxfrw: `0b7b7b709d9299565db603f878214656ef5e9ddf`
- Eigen: `3147391d946bb4b6c68edd901f2add6ac1f31f8c` (`3.4.0`)
- mimalloc: `f819dbb4e4813fab464aee16770f39f11476bfea` (`v2.0.5-74-gf819dbb4`)

## Upgrade targets selected
- libdxfrw: latest `master` in SolveSpace fork
  - `8359399ff3eb96aec14fb160c9a5bc4796b60717`
- Eigen: stable patch release `3.4.1`
  - `d71c30c47858effcbd39967097a2d99ee48db464`
- mimalloc: stable release tag `v2.2.7`
  - tag object `96d2db36...`, checked out commit `6a53d72d46a1a641d8e5793db37cb2da60e04192`

## Integration issue encountered
After updating libdxfrw, cross-Windows build failed in DXF export code due API ownership changes:
- `DRW_Polyline::vertlist` now stores `std::shared_ptr<DRW_Vertex>` in newer libdxfrw
- `DRW_Spline::controllist` now stores `std::shared_ptr<DRW_Coord>`
- Existing code pushed raw pointers directly.

## Compatibility fix applied
Updated `src/exportvector.cpp` with ownership-adapter helpers:
- `DrwPushOwned(std::vector<T*>, T*)`
- `DrwPushOwned(std::vector<std::shared_ptr<T>>, T*)`

Then replaced direct `push_back(new ...)` calls with `DrwPushOwned(...)` for:
- polyline vertex construction paths
- piecewise-linear bezier conversion
- spline control-point population

This keeps compatibility with both older and newer libdxfrw container types.

## Validation
Rebuilt cross-Windows tree (`ToolTime_win`) after updates and fix:
- configure succeeded
- full build completed to 100%
- targets built include:
  - `solvespace.exe`
  - `solvespace-cli.exe`
  - `solvespace-testsuite.exe`
  - `solvespace-debugtool.exe`
  - `solvespace-benchmark.exe`
  - `CDemo.exe`

## Resulting updated pointers
- `extlib/libdxfrw` → `8359399f...`
- `extlib/eigen` → `d71c30c4...` (`3.4.1`)
- `extlib/mimalloc` → `6a53d72d...` (`v2.2.7`)
