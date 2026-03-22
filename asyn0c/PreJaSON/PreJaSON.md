# PreJaSON (Predicate-JSON / Prejudice-JSON)

A Unicode-structural data format with JSON-like recursive semantics and explicit atoms.

## Purpose

PreJaSON keeps the JSON data model (objects, arrays, strings, numbers, booleans, null) but replaces common ASCII structural punctuation with Unicode glyphs that are typically neutral in shell contexts.

This improves reliability in workflows where nested escaping layers frequently fail.

## Structural Glyphs

| Meaning | Glyph | Unicode |
|---|---|---|
| Object start | ⟦ | U+27E6 |
| Object end | ⟧ | U+27E7 |
| Array start | ⟨ | U+27E8 |
| Array end | ⟩ | U+27E9 |
| Pair separator | ∧ | U+2227 |
| Key-value map | ↦ | U+21A6 |
| Symbol prefix (object key marker) | • | U+2022 |
| String start | ⌜ | U+231C |
| String end | ⌝ | U+231D |

## Atoms

- `go'i` → `true`
- `nago'i` → `false`
- `noda` → `null`

## Canonical Value Mapping

- PreJaSON object `⟦ ... ⟧` ↔ dictionary / map
- PreJaSON array `⟨ ... ⟩` ↔ list / collection
- PreJaSON string `⌜ ... ⌝` ↔ string
- PreJaSON number token ↔ numeric scalar
- PreJaSON atom ↔ boolean or null

## Core Forms

### Object

```
⟦ •⌜key1⌝ ↦ value1 ∧ •⌜key2⌝ ↦ value2 ⟧
```

### Array

```
⟨ value1 ∧ value2 ∧ value3 ⟩
```

### String

```
⌜text⌝
```

## Escaping (Current In-Band Mode)

Two control bytes are reserved:

- `SUB` (`0x1A`): next character is literal
- `ESC` (`0x1B`): next character literal after subtracting `0x40`

In current implementations, `SUB` is used to prefix reserved glyphs and escape-control bytes inside strings.

## Example

Input object:

```json
{
  "system": "Lazarus",
  "ide_ready": true,
  "remote_deploy": false,
  "error_log": null,
  "parameters": [1, 1.5, 2025],
  "config": {
    "host": "127.0.0.1",
    "port": 8080
  }
}
```

Encoded PreJaSON:

```
⟦ •⌜system⌝ ↦ ⌜Lazarus⌝ ∧ •⌜ide_ready⌝ ↦ go'i ∧ •⌜remote_deploy⌝ ↦ nago'i ∧ •⌜error_log⌝ ↦ noda ∧ •⌜parameters⌝ ↦ ⟨ 1 ∧ 1.5 ∧ 2025 ⟩ ∧ •⌜config⌝ ↦ ⟦ •⌜host⌝ ↦ ⌜127.0.0.1⌝ ∧ •⌜port⌝ ↦ 8080 ⟧ ⟧
```

## Implementations in This Repository

- JavaScript codec: [asyn0c/PreJaSON/PreJaSON.js](asyn0c/PreJaSON/PreJaSON.js)
- VBA codec: [asyn0c/PreJaSON/PreJaSON.cls](asyn0c/PreJaSON/PreJaSON.cls)
- VBA test harness: [asyn0c/PreJaSON/test_50_PreJaSON.bas](asyn0c/PreJaSON/test_50_PreJaSON.bas)

## Out-of-Band Escaping (Design Direction)

An optional future mode can preserve payload blob length by storing substitutions outside the primary blob.

Proposed approach (high-level):

1. Keep primary payload in PreJaSON form without in-band growth where required.
2. Store substitution metadata in an adjacent channel (e.g., neighboring spreadsheet cell / tuple field).
3. Reconstruct literal content deterministically during decode.
4. Use a compact run-based encoding (RLE-inspired) for substitution ranges.

This keeps the current in-band mode (`SUB`-prefix) as baseline while enabling fixed-length-sensitive workflows.

## Notes for Tooling and API Usage

- Use tag name `PreJaSON` when selecting format explicitly.
- PreJaSON is text-based and UTF-8 safe.
- In multi-layer command pipelines, prefer file-based handoff for large payloads and repeated command invocations.
