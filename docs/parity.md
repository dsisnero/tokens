# Parity Tracking

The project maintains a complete inventory of upstream Rust source API and test coverage under `plans/inventory/`. Parity is validated via automated scripts synced from the `cross-language-crystal-parity` skill.

## Manifests

| Manifest | Tracks | Items |
|---|---|---|
| `rust_port_inventory.tsv` | Every public API item (struct, enum, method, function, trait, test) with port status | 757 |
| `rust_source_parity.tsv` | Source-level API declarations and their match status | 515 |
| `rust_test_parity.tsv` | Test coverage: each upstream `#[test]` and its Crystal spec | 242 |

## Status Vocabulary

| Status | Meaning |
|---|---|
| `ported` | Fully ported with Crystal spec coverage |
| `partial` | Ported with known behavioral differences (e.g., Unigram esaxx) |
| `skipped` | Intentional divergence (Crystal idioms differ, not applicable) |
| `missing` | Not yet ported |

## Running Parity Checks

```bash
# Validate port inventory
bash scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tokenizers/tokenizers rust

# Validate source API coverage
bash scripts/check_source_parity.sh . plans/inventory/rust_source_parity.tsv vendor/tokenizers/tokenizers rust

# Validate test coverage
bash scripts/check_test_parity.sh . plans/inventory/rust_test_parity.tsv vendor/tokenizers/tokenizers rust

# Full adversarial verification (inventory + specs + format)
bash scripts/verify_parity_adversarial.sh . vendor/tokenizers/tokenizers rust 'crystal spec' ''
```

## Current Parity (2026-05-11)

- **Test coverage**: 241 ported, 1 partial (Unigram esaxx), 0 missing
- **Port inventory**: 682 ported, 2 partial, 73 skipped (53 intentional divergences, 5 benchmarks/examples/bindings)
- **Source parity**: 515 API items tracked, 0 missing
- **Specs**: 299 examples, 0 failures, 0 errors, 0 pending
- **Adversarial verification**: PASSED

## Intentional Divergences

The 53 `skipped` items are genuine divergences where Crystal idioms differ from Rust:

| Category | Count | Rationale |
|---|---|---|
| Crystal serde/error patterns | 15 | Crystal uses exceptions instead of `Result`, explicit JSON parsing instead of serde |
| Crystal constructor patterns | 8 | Method chaining instead of Rust builder pattern |
| Mutable accessor patterns | 4 | Crystal properties with setters instead of `_mut` getters |
| Type system differences | 5 | Crystal native tuples, union types instead of Rust type aliases |
| Benchmarks | 3 | Require large data files; not ported |
| WASM examples | 2 | Not applicable to Crystal CLI |
| Node/Python bindings | 15 | Outside Crystal scope |
| Others | 1 | Trim offset tracking handled differently |
