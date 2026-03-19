# zlib update log

Date: 2026-03-19

## Requested objective
Upgrade `extlib/zlib` from the old 2016 snapshot to a stable release tag (not development).

## Starting point
- Submodule path: `extlib/zlib`
- Previous pinned commit: `2fa463b`
- Previous tag: `v1.2.9` (2016)

## Actions performed
1. Confirmed submodule remote and branch topology (`origin` at `https://github.com/madler/zlib`).
2. Fetched release tags in submodule.
3. Chose latest stable release tag: `v1.3.2`.
4. Checked out `v1.3.2` in `extlib/zlib`.
5. Committed parent-repo submodule pointer update:
   - Parent commit: `3dd1d7c`
   - Message: `extlib/zlib: bump submodule to zlib v1.3.2 release`

## Immediate integration result
A post-upgrade Windows cross-build exposed a downstream compatibility guard in libpng:

- Failure point: `extlib/libpng/pngpriv.h`
- Error:
  - `#error ZLIB_VERNUM != PNG_ZLIB_VERNUM ...`

Observed reason:
- Existing generated build header had stale value `PNG_ZLIB_VERNUM 0x1290` (zlib 1.2.9) while zlib submodule had been moved to `1.3.2`.

## Outcome
- zlib upgrade itself completed successfully and is committed in parent repo.
- Additional follow-up was required in `libpng` to align with the new zlib release.
- Follow-up is documented in `asyn0c/update_log/libpng.md`.
