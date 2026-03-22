# Export Layer Naming — User Preference via Property Browser

## Purpose and Motivation

The export layer naming strategy must be a **persistent per-installation preference**,
not a per-file setting. The choice affects every DXF/SVG export from that workstation and
must survive application restarts.

The preference space is intentionally reduced to **exactly two modes**:

1. **Style number ON** (`s%03d_...`)
2. **Style number OFF** (`...`)

No third naming mode is supported.

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
{ 1, N_("&Export Layer Names..."), Command::SVG_LAYER_NAMES, 0, KN, mFile },
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
bool     exportLayerNamesWithStyleNumber; // true = style number ON
                                         // false = style number OFF
```

Default can be either policy choice; recommended default is `false` (style number OFF).

---

## Persistence

### Load (`SolveSpaceUI::Init`, `src/solvespace.cpp`)

Alongside the existing `ThawBool` calls:

```cpp
exportLayerNamesWithStyleNumber = settings->ThawBool("ExportLayerNamesWithStyleNumber", false);
```

### Save (`SolveSpaceUI::Exit`, `src/solvespace.cpp`)

Alongside the existing `FreezeBool` calls:

```cpp
settings->FreezeBool("ExportLayerNamesWithStyleNumber", exportLayerNamesWithStyleNumber);
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
    Printf(true,  "%FtEXPORT LAYER NAMING CONVENTION%E");

    Printf(true,  "%Ft layer names written to DXF and SVG%E");
    Printf(false, "");
    Printf(false, "  %Fd%f%LN%s  style number OFF (new)%E",
        &ScreenChangeSvgLayerNames,
        !SS.exportLayerNamesWithStyleNumber ? RADIO_TRUE : RADIO_FALSE);
    Printf(false, "%Ba   e.g.  s100-chop   →  chop");
    Printf(false, "%Ba         #def-inactive-group   →  _def_inactive_group");
    Printf(false, "");
    Printf(false, "  %Fd%f%LO%s  style number ON (old)%E",
        &ScreenChangeSvgLayerNames,
        SS.exportLayerNamesWithStyleNumber ? RADIO_TRUE : RADIO_FALSE);
    Printf(false, "%Bd   e.g.  s100-chop   →  s100_chop");
    Printf(false, "%Bd         #def-inactive-group   →  s002_def_inactive_group");

    Printf(false, "");
    Printf(false, "Non-alphanumeric characters are always converted to '_'.");
    Printf(false, "If style number OFF causes a collision, colliding names are");
    Printf(false, "promoted to s???_<name> for manual resolution.");

    Printf(false, "");
    Printf(true,  "(or %Fl%Ll%fback to home screen%E)", &ScreenHome);
}
```

The link letters `'N'` and `'O'` (new / old) are passed to the callback via `%L`:

```cpp
void TextWindow::ScreenChangeSvgLayerNames(int link, uint32_t v) {
    SS.exportLayerNamesWithStyleNumber = (link == 'O');
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

## Name Integration (DXF + SVG)

The flag is read at export time in shared naming logic used by both DXF and SVG:

```cpp
static std::string SvgLayerNameForStyle(hStyle hs) {
    Style *s = Style::Get(hs);

    std::string name = SanitizeStyleName(s->name); // non-alnum -> '_'

    if(SS.exportLayerNamesWithStyleNumber) {
        return ssprintf("s%03x_%s", hs.v, name.c_str());
    }

    // Style number OFF by default.
    // Collision handling upgrades colliding names to s???_<name>.
    return ResolveCollisionOrBare(hs, name);
}
```

Any fixed-string translation helpers are deleted in both paths.

---

## Declaration additions summary

| File | Addition |
|---|---|
| `src/solvespace.h` | `bool exportLayerNamesWithStyleNumber;` on `SolveSpaceUI` |
| `src/ui.h` | `Screen::SVG_LAYER_NAMES = 10` |
| `src/ui.h` | `static void ScreenChangeSvgLayerNames(int link, uint32_t v);` |
| `src/ui.h` | `void ShowSvgLayerNames();` |
| `src/graphicswin.cpp` | `Command::SVG_LAYER_NAMES` menu entry after `SAVE_AS` |
| `src/graphicswin.cpp` | `case Command::SVG_LAYER_NAMES:` in `MenuFile()` switch |
| `src/solvespace.cpp` | `ThawBool("ExportLayerNamesWithStyleNumber", false)` in `Init()` |
| `src/solvespace.cpp` | `FreezeBool("ExportLayerNamesWithStyleNumber", ...)` in `Exit()` |
| `src/confscreen.cpp` | `ShowSvgLayerNames()` and `ScreenChangeSvgLayerNames()` |
| `src/exportvector.cpp` | Shared sanitized naming logic for DXF/SVG; delete fixed-string helpers |
| `src/textwin.cpp` | `case Screen::SVG_LAYER_NAMES:` in `Show()` switch |
