# SVG Export Layer Naming — Alignment with DXF Convention

## What DXF actually uses as layer names

In `assignEntityDefaults` (`src/exportvector.cpp`):
```cpp
entity->layer = s->DescriptionString();
```

And `DescriptionString()` (`src/style.cpp`) always produces:
```
s%03x-%s   →  e.g. "s001-#def-active-grp", "s003-#def-inactive-grp", "s100-chop"
```

The `writeLayers()` override also emits two *unconditional* fixed-string layers — `"dimensions"` and `"text"` — for constraints; those are not style-derived at all.

---

## What the current SVG naming chain does instead

```
SvgLayerNameForStyle(hs)
 ├─ if name is set AND does NOT start with "#def-"  →  return name as-is  ("chop")
 ├─ else call SvgSystemFallbackLayerName(h.v):
 │    case 0  → "#references"
 │    case 1  → "active_group"       (h.v=1 = ACTIVE_GRP  ✓)
 │    case 2  → "inactive_group"     (h.v=2 = CONSTRUCTION ← BUG; INACTIVE_GRP is h.v=3)
 │    case 6  → "dimensions"         (h.v=6 = CONSTRAINT   ← BUG; DXF "dimensions" is hardcoded)
 │    default (h.v<0x100) → "system_s%x"
 └─ final fallback: name as-is, or "s%x"
```

The `#def-` prefix check exists solely so that system styles (whose `name` is `"#def-active-grp"`,
`"#def-inactive-grp"`, etc.) are *not* emitted with those raw names — they are redirected to the
hardcoded friendly strings above.

---

## What happens under the proposed alignment

**`SvgLayerNameForStyle()` collapses to a single call:**

```cpp
static std::string SvgLayerNameForStyle(hStyle hs) {
    return Style::Get(hs)->DescriptionString();
}
```

Three bodies of logic become dead code and should be deleted:

| Function | Fate |
|---|---|
| `SvgSystemFallbackLayerName()` | Entirely superseded — all its cases are now covered by `DescriptionString()` |
| `SvgHasDefaultStyleNamePrefix()` | Entirely superseded — the `#def-` gate was only needed to redirect to the fallback |
| The multi-branch body of `SvgLayerNameForStyle()` | Replaced by the one-liner above |

`SvgLayerId()` stays unchanged — it still sanitises whatever string it receives.

---

## Name changes for the sub-`0x100` (system) styles

| h.v | Symbol | Current SVG layer name | New SVG layer name (= DXF layer name) |
|---|---|---|---|
| 1 | `ACTIVE_GRP` | `active_group` | `s001-#def-active-grp` |
| 2 | `CONSTRUCTION` | `inactive_group` ← **wrong handle** | `s002-#def-construction` |
| 3 | `INACTIVE_GRP` | `system_s3` ← **never named correctly** | `s003-#def-inactive-grp` |
| 4 | `DATUM` | `system_s4` | `s004-#def-datum` |
| 5 | `SOLID_EDGE` | `system_s5` | `s005-#def-solid-edge` |
| 6 | `CONSTRAINT` | `dimensions` ← **wrong meaning** | `s006-#def-constraint` |
| 7–15 | … | `system_s%x` | `s00%x-#def-…` |

The two bugs in `SvgSystemFallbackLayerName` — h.v=2 mapped to `"inactive_group"` and h.v=6
mapped to `"dimensions"` — are silently corrected by removing the function entirely. Neither bug
was visible in practice: `CONSTRUCTION` has `exportable=false` so it never appeared in exports,
and `CONSTRAINT` entities in DXF go to the hardcoded `"dimensions"` layer via a separate path,
not via `DescriptionString()`.

---

## Effect on the `id` attribute

`SvgLayerId()` collapses runs of non-alphanumeric characters to a single `_`, so:

```
"s001-#def-active-grp"    →  id="s001_def_active_grp"
"s003-#def-inactive-grp"  →  id="s003_def_inactive_grp"
"s100-chop"               →  id="s100_chop"
```

The `data-name` / `inkscape:label` attributes carry the exact DXF string with its dashes and
`#def-` prefix intact.

---

## Net summary

Adopting `DescriptionString()` universally eliminates all special-case SVG naming logic below
`FIRST_CUSTOM` (`0x100`). The current human-friendly SVG names (`active_group`, `inactive_group`)
are replaced by their exact DXF counterparts (`s001-#def-active-grp`, `s003-#def-inactive-grp`).
Custom styles gain the `s%03x-` handle prefix in SVG that they already have in DXF
(`chop` → `s100-chop`). The only remaining naming code is `SvgLayerId()` for XML-safe `id`
sanitisation.
