# SVG Export Layer Naming — User Preference via Property Browser

## Purpose and Motivation

The SVG layer naming convention (old: `s%03x-name` / new: bare `name`) must be a
**persistent per-installation preference**, not a per-file setting.  The choice affects
every SVG export from that workstation and must survive application restarts.

Downstream consumers that perform exact-string matching on SVG layer labels — the
Kongsberg plotter and the Illustrator conversion script — will silently fail if the
naming convention changes between sessions.  The user must be able to set the convention
once and never think about it again.

---

## Menu Entry Placement

The preference is exposed via a new menu entry placed **immediately after "Save As..."**
in the File menu (`graphicswin.cpp`, `Menu[]` table).  A separator already exists there;
the new entry goes between "Save As..." and that separator.

Relevant section of the `Menu[]` table (current state):

```cpp
{ 1, N_("&Save"),              Command::SAVE,    C|'s',   KN, mFile },
{ 1, N_("Save &As..."),        Command::SAVE_AS, C|S|'s', KN, mFile },
{ 1,  NULL,                    Command::NONE,    0,       KN, NULL  },   // ← separator
{ 1, N_("Export &Image..."),   ...
```

New entry inserted between "Save As..." and the separator:

```cpp
{ 1, N_("&SVG Layer Names..."), Command::SVG_LAYER_NAMES, 0, KN, mFile },
```

The handler in `MenuFile()` (or its equivalent switch) navigates to the new screen:

```cpp
case Command::SVG_LAYER_NAMES:
    SS.TW.GoToScreen(TextWindow::Screen::SVG_LAYER_NAMES);
    SS.ScheduleShowTW();
    break;
```

No keyboard accelerator is needed; this is an infrequent configuration action.

---

## New `Screen` Enum Value

`src/ui.h` — `TextWindow::Screen` enum, currently ending at `TANGENT_ARC = 9`:

```cpp
enum class Screen : uint32_t {
    LIST_OF_GROUPS      = 0,
    GROUP_INFO          = 1,
    GROUP_SOLVE_INFO    = 2,
    CONFIGURATION       = 3,
    STEP_DIMENSION      = 4,
    LIST_OF_STYLES      = 5,
    STYLE_INFO          = 6,
    PASTE_TRANSFORMED   = 7,
    EDIT_VIEW           = 8,
    TANGENT_ARC         = 9,
    SVG_LAYER_NAMES     = 10    // ← new
};
```

The dispatch `switch` in `TextWindow::Show()` (`textwin.cpp`) gains one case:

```cpp
case Screen::SVG_LAYER_NAMES: ShowSvgLayerNames(); break;
```

---

## Application State Field

`src/solvespace.h` — one new `bool` alongside the existing export flags:

```cpp
bool     exportSvgBareLayerNames;   // true = new convention (bare name)
                                    // false = old convention (s%03x-name)
```

Default: `true` (new convention, for new installations).  Existing installations that
have never set this key will also receive `true` on first run.  If backward-compat is
preferred, default to `false` until the user explicitly opts in.

---

## Persistence

### Load (`SolveSpaceUI::Init`, `src/solvespace.cpp`)

Alongside the existing `ThawBool` calls:

```cpp
exportSvgBareLayerNames = settings->ThawBool("ExportSvgBareLayerNames", true);
```

### Save (`SolveSpaceUI::Exit`, `src/solvespace.cpp`)

Alongside the existing `FreezeBool` calls:

```cpp
settings->FreezeBool("ExportSvgBareLayerNames", exportSvgBareLayerNames);
```

The settings store is platform-native (registry on Windows, plist on macOS, INI-like file
on Linux/GTK) and is already abstracted behind `Platform::Settings`.  No new plumbing is
required.

---

## Property Browser Page — `ShowSvgLayerNames()`

New function in `src/confscreen.cpp` (or a new `src/exportscreen.cpp` if the file becomes
large), following the exact pattern of `ShowTangentArc()`:

```cpp
void TextWindow::ShowSvgLayerNames() {
    Printf(true,  "%FtSVG LAYER NAMING CONVENTION%E");

    Printf(true,  "%Ft layer name written to SVG <g> elements%E");
    Printf(false, "");
    Printf(false, "  %Fd%f%LN%s  new convention — bare name%E",
        &ScreenChangeSvgLayerNames,
        SS.exportSvgBareLayerNames ? RADIO_TRUE : RADIO_FALSE);
    Printf(false, "%Ba   e.g.  chop   →  id=\"chop\"");
    Printf(false, "");
    Printf(false, "  %Fd%f%LO%s  old convention — handle-prefixed name%E",
        &ScreenChangeSvgLayerNames,
        !SS.exportSvgBareLayerNames ? RADIO_TRUE : RADIO_FALSE);
    Printf(false, "%Bd   e.g.  chop   →  id=\"s100_chop\"");

    Printf(false, "");
    Printf(false, "The new convention produces stable layer names that");
    Printf(false, "do not change when styles are reordered or renumbered.");
    Printf(false, "Use it when a downstream consumer (plotter, script)");
    Printf(false, "matches layer names by exact string.");

    Printf(false, "");
    Printf(true,  "(or %Fl%Ll%fback to home screen%E)", &ScreenHome);
}
```

The link letters `'N'` and `'O'` (new / old) are passed to the callback via `%L`:

```cpp
void TextWindow::ScreenChangeSvgLayerNames(int link, uint32_t v) {
    SS.exportSvgBareLayerNames = (link == 'N');
    SS.GW.Invalidate();
}
```

No edit control is needed — this is a binary radio choice, matching the pattern used for
`ScreenChangeCanvasSizeAuto` (fixed / auto radio pair in `ShowConfiguration()`).

---

## `Command` Enum Addition

`src/solvespace.h` or `src/ui.h` — wherever `Command` is declared, add:

```cpp
SVG_LAYER_NAMES,
```

in the `File` command group, near `SAVE_AS`.

---

## `SvgLayerNameForStyle()` Integration

The flag is read at export time inside `SvgLayerNameForStyle()`:

```cpp
static std::string SvgLayerNameForStyle(hStyle hs) {
    Style *s = Style::Get(hs);

    if(SS.exportSvgBareLayerNames) {
        // New convention: strip "#def-" sentinel, return bare name.
        std::string name = s->name;
        if(name.rfind("#def-", 0) == 0) name = name.substr(5);
        if(!name.empty()) return name;
        return ssprintf("s%x", hs.v);   // unnamed style fallback
    } else {
        // Old convention: full DescriptionString(), matching DXF layer name.
        return s->DescriptionString();
    }
}
```

`SvgSystemFallbackLayerName()` and `SvgHasDefaultStyleNamePrefix()` are **deleted** in
both paths — the old convention now delegates to `DescriptionString()` directly rather
than maintaining a separate hardcoded table (which was also buggy; see
`export-strategy-old-convention.md`).

---

## Declaration additions summary

| File | Addition |
|---|---|
| `src/solvespace.h` | `bool exportSvgBareLayerNames;` on `SolveSpaceUI` |
| `src/ui.h` | `Screen::SVG_LAYER_NAMES = 10` |
| `src/ui.h` | `static void ScreenChangeSvgLayerNames(int link, uint32_t v);` |
| `src/ui.h` | `void ShowSvgLayerNames();` |
| `src/graphicswin.cpp` | `Command::SVG_LAYER_NAMES` menu entry after `SAVE_AS` |
| `src/graphicswin.cpp` | `case Command::SVG_LAYER_NAMES:` in `MenuFile()` switch |
| `src/solvespace.cpp` | `ThawBool("ExportSvgBareLayerNames", true)` in `Init()` |
| `src/solvespace.cpp` | `FreezeBool("ExportSvgBareLayerNames", ...)` in `Exit()` |
| `src/confscreen.cpp` | `ShowSvgLayerNames()` and `ScreenChangeSvgLayerNames()` |
| `src/exportvector.cpp` | Updated `SvgLayerNameForStyle()`, delete two helper functions |
| `src/textwin.cpp` | `case Screen::SVG_LAYER_NAMES:` in `Show()` switch |
