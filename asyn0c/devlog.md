# Build Log Warning & Stability Report (Ubuntu script run)

Date of run: 2026-03-16  
Script: [asyn0c/,test,tooltime,ubuntu](asyn0c/,test,tooltime,ubuntu)  
Full build log: [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log)

## 1) Build result summary

- Final status: **success**.
- Test result: **254 test cases passed, 0 skipped, 879 checks**.
- Confirmation lines:
  - [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1557)
  - [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1558)

## 2) What would stop this script when rerun

Before this update, the script stopped on `mkdir tooltime_lin` if that folder already existed.

After this update, behavior is:

1. If `tooltime_lin` exists, read its **birth/creation time** (`stat -c %W`).
2. Rename it to `tooltime_lin--YYYY-MM-DD--HH-MM-SS` using that creation timestamp.
3. Create a fresh `tooltime_lin` and continue build/test.
4. If birth time is unavailable (`%W < 0`) or target archive name exists, script exits with a clear error.

## 3) Comprehensive warning inventory and stability impact

---

### A. Deprecated copy-assignment warnings in DXF export path

Representative lines:
- [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L514-L523)
- Triggered from [src/exportvector.cpp](src/exportvector.cpp#L126-L132)
- Related vendor type declarations in `extlib/libdxfrw/drw_entities.h`

Observed warning class:
- `-Wdeprecated-copy`

Interpretation:
- Assignment `polyline = {}` triggers copy-assignment behavior involving libdxfrw classes that have user-defined copy constructors but no explicit copy-assignment operators.
- This is primarily a **modern C++ API hygiene warning** (rule-of-three/five style issue), not an immediate crash indicator.

Program stability impact:
- **Low immediate runtime risk** in this run (build and tests pass).
- **Medium maintenance risk** over time if compiler strictness increases or if semantics of copied entities become more complex.

---

### B. Non-trivial object zeroing via `memset`

Representative lines:
- [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L612-L618)
- Source site: [src/textwin.cpp](src/textwin.cpp#L287-L291)

Observed warning class:
- `-Wclass-memaccess`

Interpretation:
- `memset(this, 0, sizeof(*this))` is used on `TextWindow`, which is a non-trivially assignable class.
- The code comments explicitly acknowledge this as a deliberate workaround to avoid stack issues from whole-object assignment.

Program stability impact:
- **Moderate structural risk** if class internals evolve (new non-POD members, stronger invariants, additional ownership semantics).
- It appears currently controlled by manual restoration of selected members and has not failed this test run.
- This warning is the strongest “future fragility” signal in the current project-owned code.

---

### C. `std::regex` / libstdc++ “may be used uninitialized” warnings during test harness compile

Representative lines:
- [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L639-L652)
- Many repeats of the same pattern in libstdc++ internals (`std_function.h`, `regex_automaton*.h`, `regex_compiler.tcc`)
- Trigger context includes [test/harness.cpp](test/harness.cpp#L5-L6)

Observed warning class:
- `-Wmaybe-uninitialized`

Interpretation:
- Warnings originate in inlined standard-library internals under optimization.
- This pattern is commonly seen as **compiler-analysis false positives** around `std::regex` internals.

Program stability impact:
- **Low direct product risk**; appears in test-code compilation path and standard library internals.
- If this ever became `-Werror` globally, it could become a build-friction issue rather than a runtime correctness issue.

---

### D. Missing translation strings at test runtime

Representative lines:
- [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1180-L1181)

Messages:
- `Missing (absent) translation for group-name'#references'`
- `Missing (absent) translation for group-name'sketch-in-plane'`

Interpretation:
- Locale catalog is missing some keys.

Program stability impact:
- **No core stability risk**.
- UX/localization completeness issue only.

---

### E. mimalloc warnings about very large/aligned allocations and pointer region checks

Representative lines:
- [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1182-L1206)

Messages include:
- fallback to over-allocation for large aligned allocation
- `mi_usable_size` / `mi_free` “might not point to a valid heap region”, followed by explicit confirmation that pointer was valid

Interpretation:
- mimalloc diagnostics indicate conservative checks and fallback behavior under large allocation/alignment constraints.
- Log itself confirms pointers were valid after verification.

Program stability impact:
- **Low risk in this observed run**.
- More of an allocator diagnostics/noise profile under stress scenarios than evidence of confirmed heap corruption.

---

### F. Runtime diagnostic prints during tests (`Vector::WithMagnitude(1) of zero vector!`, `Not implemented`)

Representative lines:
- e.g. [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1208)
- e.g. [build-tooltime-ubuntu.log](build-tooltime-ubuntu.log#L1404)

Interpretation:
- Internal diagnostics emitted while specific test paths are exercised.
- Since the corresponding tests report `OK`, these are expected/handled scenarios or debug-level notices.

Program stability impact:
- **Low immediate risk** for this build/test outcome.
- Worth tracking if frequency increases or if these diagnostics start correlating with sanitizer aborts.

## 4) Overall stability conclusion

- This run is **functionally healthy** under a strict debug/sanitizer build profile: compile completed and full scripted tests passed.
- No fatal compiler errors or sanitizer aborts were observed.
- Highest-priority long-term code-quality warning is the `memset(this, 0, ...)` use in [src/textwin.cpp](src/textwin.cpp#L287-L291).
- Remaining warnings are mostly vendor/toolchain/test-runtime noise with lower direct impact on present runtime stability.

## 5) Suggested follow-ups (optional)

1. Evaluate replacing raw object zeroing in `TextWindow::ClearSuper()` with a safer reset strategy preserving performance constraints.
2. Consider targeted suppression or toolchain pinning for known libstdc++ `std::regex` false positives in test builds.
3. Track localization key coverage for missing `group-name` entries.
4. If desired, make the script auto-handle archive-name collisions when identical birth-time suffix already exists.
