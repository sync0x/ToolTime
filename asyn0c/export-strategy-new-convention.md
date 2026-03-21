# SVG Export Layer Naming — New Convention: Stable Bare Names

## Intent

SVG layer names must be **stable across style reordering and renumbering**.

Two downstream consumers perform exact-string matching on SVG layer names:

1. **Kongsberg plotter** — reads the SVG layer name to select the physical tooling for that
   layer (e.g. knife, pen, router bit). If a new style is inserted and `chop` shifts from
   `s100-chop` to `s101-chop`, the plotter no longer recognises the layer and falls back to
   a default or errors out.

2. **Illustrator conversion script** — inspects layer names to infer the probable tool each
   layer represents and route artwork accordingly. Same fragility: a handle change silently
   breaks the hint lookup.

The `s%03x-` prefix embedded by `Style::DescriptionString()` is derived from the style's
internal handle, which is an insertion-order integer. It changes whenever styles are added,
removed, or the file is rebuilt from scratch. It is therefore unsuitable as a stable external
identifier.

The new convention is: **SVG group names are the bare user-visible name only, with no handle
prefix.**

---

## Mapping from internal name to SVG layer name

### Custom styles (`h.v >= 0x100`)

The `Style::name` field holds whatever the user typed (e.g. `chop`, `score`, `engrave`).
It is used verbatim. No prefix, no handle.

| Internal `DescriptionString()` | New SVG layer name |
|---|---|
| `s100-chop` | `chop` |
| `s101-score` | `score` |
| `s102-engrave` | `engrave` |

This is already the behaviour of the *current* `SvgLayerNameForStyle()` for custom styles —
the new convention simply formalises it and eliminates all the special-case machinery below.

### System styles (`h.v < 0x100`)

System styles store their name with the `#def-` prefix (e.g. `#def-active-grp`,
`#def-inactive-grp`). The `#def-` prefix is an internal sentinel that signals "this name was
machine-generated, not user-assigned". Under the new convention it is stripped to yield the
human-readable suffix.

| h.v | Symbol | `Style::name` | New SVG layer name |
|---|---|---|---|
| 1 | `ACTIVE_GRP` | `#def-active-grp` | `active-grp` |
| 2 | `CONSTRUCTION` | `#def-construction` | `construction` |
| 3 | `INACTIVE_GRP` | `#def-inactive-grp` | `inactive-grp` |
| 4 | `DATUM` | `#def-datum` | `datum` |
| 5 | `SOLID_EDGE` | `#def-solid-edge` | `solid-edge` |
| 6 | `CONSTRAINT` | `#def-constraint` | `constraint` |
| 14 | `HIDDEN_EDGE` | `#def-hidden-edge` | `hidden-edge` |
| 15 | `OUTLINE` | `#def-outline` | `outline` |

Most system styles are not exportable and will never appear as SVG layers; this table is
exhaustive for completeness.

---

## Implementation

### `SvgLayerNameForStyle()` — replacement

```cpp
static std::string SvgLayerNameForStyle(hStyle hs) {
    Style *s = Style::Get(hs);
    std::string name = s->name;
    // Strip the "#def-" sentinel used internally for system styles.
    if(name.rfind("#def-", 0) == 0) {
        name = name.substr(5);
    }
    if(!name.empty()) return name;
    // Last-resort fallback: truly unnamed style (should not occur in practice).
    return ssprintf("s%x", hs.v);
}
```

### Dead code to delete

| Function | Reason |
|---|---|
| `SvgSystemFallbackLayerName()` | Replaced by the `#def-` strip; all its hardcoded cases were also incorrect (see old-convention doc) |
| `SvgHasDefaultStyleNamePrefix()` | The `#def-` check is now inlined into `SvgLayerNameForStyle()` and used to *strip*, not gate |

`SvgLayerId()` is unchanged — it still sanitises the bare name for use as an XML `id`.

---

## Attribute assignment in the emitted `<g>` element

```xml
<g id="s100_chop"
   data-name="chop"
   inkscape:label="chop"
   inkscape:groupmode="layer">
```

- **`id`** — sanitised form of the bare name (non-alphanumerics collapsed to `_`), prefixed
  with the handle to guarantee uniqueness in the unlikely event two styles have the same name
  after sanitisation. The handle prefix in the `id` is acceptable because `id` is an internal
  XML identifier, not a consumer-visible layer label.
- **`data-name`** and **`inkscape:label`** — the exact bare name, unsanitised, as it appears in
  the Line Styles registry. These are what Kongsberg and the Illustrator script read.

---

## Stability guarantee

Because the bare name is set by the user and stored verbatim in the `.slvs` file as
`Style.name`, it is invariant under:

- Insertion or deletion of other styles
- Reordering styles in the registry
- Moving the file to a different machine or rebuilding from a fresh CMake configure
- Any future increase to `FIRST_CUSTOM` (currently `0x100`)

Only a deliberate rename of the style by the user changes the SVG layer name, which is the
correct and expected behaviour.

---

## Relationship to DXF

DXF layer names continue to use `Style::DescriptionString()` (i.e. `s%03x-%s`) unchanged.
The handle prefix in DXF is harmless there because DXF consumers in this workflow (LibreCAD,
AutoCAD) do not perform exact-name tool dispatch; they use the layer as a visual grouping only.

SVG and DXF layer names therefore deliberately diverge. The SVG name is the stable external
identifier; the DXF name retains its handle for round-trip fidelity and disambiguation within
the CAD environment.
