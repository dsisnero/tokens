# AGENTS.md — tokens (Crystal port of huggingface/tokenizers)

## Source of Truth

- **Upstream**: https://github.com/huggingface/tokenizers
- **Upstream ref (current)**: `3992692` — `main` branch
- **Submodule path**: `vendor/tokenizers`
- **Core Rust crate**: `vendor/tokenizers/tokenizers/`

Upstream behavior is the source of truth. All porting decisions must preserve upstream semantics, parameter ordering, edge-case handling, and error behavior.

## Workflow

1. Lock upstream revision in branch notes.
2. Use `cross-language-crystal-parity` for inventory/drift tracking.
3. Translate Rust -> Crystal preserving exact behavior.
4. Port Rust tests as Crystal specs.
5. Run quality gates before marking complete:
   - `crystal tool format --check src spec`
   - `ameba src spec`
   - `crystal spec`

## Directory Layout

```
src/tokens.cr          # Main entry point
spec/                   # Crystal specs (port of upstream tests)
vendor/tokenizers/      # Upstream submodule
plans/inventory/        # Parity inventory manifests
```

## Language Mapping (Rust -> Crystal)

| Rust | Crystal |
|------|---------|
| `mod foo` | `module Foo` |
| `const X: u8 = 1` | `X = 1_u8` |
| `enum` | `enum` or tagged union |
| `Result<T, E>` | exception or union type |
| `Option<T>` | `T?` |
| `#[test]` | `it` blocks |
| `Vec<u8>` | `Bytes` / `Slice(UInt8)` |
| `String` | `String` |
| `&str` | `String` |
