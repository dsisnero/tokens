# docs/coding-guidelines.md

## Coding Guidelines

- Follow upstream Rust semantics exactly — parameter order, edge cases, and error behavior must match.
- Use `Bytes` (Slice(UInt8)) for binary data, not `String`.
- Prefer explicit numeric widths (`_u8`, `_i32`, etc.) where behavior depends on signedness/range.
- Preserve half-open range semantics (start..end, not start..=end).
- Port upstream tests as Crystal specs; do not weaken assertions.
