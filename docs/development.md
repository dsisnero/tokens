# docs/development.md

## Prerequisites

- Crystal >= 1.20.0
- Rust (for building upstream verification tests, optional)

## Setup

```bash
git submodule update --init --recursive
make install
```

## Quality Gates

Run all quality gates before committing:

```bash
make format
make lint
make test
```

## Adding New Ports

1. Lock upstream revision.
2. Create or update `plans/inventory/rust_port_inventory.tsv`.
3. Port Rust source file to Crystal under `src/tokens/`.
4. Port corresponding tests to `spec/`.
5. Run quality gates.
