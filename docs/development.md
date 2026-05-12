# Development

## Prerequisites

- Crystal >= 1.20.0
- Ruby (for parity scripts)

## Setup

```bash
git clone https://github.com/dsisnero/tokens.git
cd tokens
git submodule update --init --recursive
make install
```

## Test Data

Integration tests require model data files from HuggingFace. Run once:

```bash
make download-data
```

This downloads BPE vocab files, tokenizer JSON files, and training data to `data/`. The `data/` directory is gitignored.

## Quality Gates

Run all quality gates before committing:

```bash
make format    # crystal tool format --check src spec
make lint      # ameba src spec
make test      # crystal spec
```

Or all at once:

```bash
make test-all  # download-data + crystal spec
```

## Parity Checks

Validate porting progress against upstream:

```bash
bash scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tokenizers/tokenizers rust
bash scripts/check_source_parity.sh . plans/inventory/rust_source_parity.tsv vendor/tokenizers/tokenizers rust
bash scripts/check_test_parity.sh . plans/inventory/rust_test_parity.tsv vendor/tokenizers/tokenizers rust
```

Full adversarial verification:

```bash
bash scripts/verify_parity_adversarial.sh . vendor/tokenizers/tokenizers rust 'crystal spec' ''
```

## Adding New Ports

1. Lock upstream revision in branch notes.
2. Create or update `plans/inventory/rust_port_inventory.tsv`.
3. Port Rust source file to Crystal under `src/tokens/`.
4. Port corresponding tests to `spec/`.
5. Update test parity and source parity manifests.
6. Run quality gates and parity checks.
