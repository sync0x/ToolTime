# Export Layer Naming — New Convention (Style Number OFF)

## Rule

The new convention removes style numbers from exported layer names for **both DXF and SVG**,
except when a collision occurs.

Name construction:

1. Start from the style's internal name.
2. Replace every non-alphanumeric character with `_`.
3. Use that sanitized token directly as the layer name.

For system styles below `s100`, the `#def` prefix is retained and therefore sanitizes to `_def`.
Example: `#def-inactive-group` → `_def_inactive_group`.

There is no hard-coded string translation table.

---

## Collision policy (rare, explicit)

If two styles sanitize to the same token but have different style indices, both colliding
names are rewritten to include style numbers:

`s???_<sanitized_name>`

where `???` is the unique style index for each colliding style.

This is intentionally obvious and manual-follow-up friendly.

---

## Examples

| Source style | Style index | Exported DXF layer | Exported SVG layer |
|---|---:|---|---|
| `#def-active-group` | 001 | `_def_active_group` | `_def_active_group` |
| `#def-inactive-group` | 002 | `_def_inactive_group` | `_def_inactive_group` |
| `s100-chop` | 100 | `chop` | `chop` |
| `s101-fold` | 101 | `fold` | `fold` |

Collision example:

| Source style | Style index | Sanitized token | Final exported name |
|---|---:|---|---|
| `s120-cut line` | 120 | `cut_line` | `s120_cut_line` |
| `s121-cut-line` | 121 | `cut_line` | `s121_cut_line` |

---

## Implementation notes

- Any fixed-string system-name translations are removed.
- SVG and DXF use the same naming rule.
- The new convention is “style number OFF by default; ON only for collisions.”
