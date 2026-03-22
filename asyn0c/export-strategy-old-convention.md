# Export Layer Naming — Old Convention (Style Number ON)

## Rule

The old convention keeps style numbers in exported layer names for **both DXF and SVG**.

Name construction:

1. Start from the style's internal name.
2. Replace every non-alphanumeric character with `_`.
3. Prefix with `s%03d_` (style index, zero-padded to 3 digits).

There is no hard-coded string translation table.

---

## Examples

| Source style | Style index | Exported DXF layer | Exported SVG layer |
|---|---:|---|---|
| `#def-active-group` | 001 | `s001_def_active_group` | `s001_def_active_group` |
| `#def-inactive-group` | 002 | `s002_def_inactive_group` | `s002_def_inactive_group` |
| `s100-chop` | 100 | `s100_chop` | `s100_chop` |
| `s101-fold` | 101 | `s101_fold` | `s101_fold` |

---

## Implications

- Layer names are stable only while style indices remain stable.
- This convention preserves index visibility for workflows that prefer explicit style handles.
- Since translation-by-fixed-strings is removed, names are fully mechanical and predictable.

---

## Removed legacy behavior

Any logic that maps specific system names to hand-written aliases (for example,
`active-grp` → `active-group`) is out of scope in this convention and should be deleted.
