# docs/testing.md

## Testing Strategy

- Every ported module has Crystal specs in `spec/`.
- Tests are ported from upstream Rust `#[test]` functions.
- Characterization specs may be added when upstream tests are insufficient.
- Fixture files used in tests reside in `spec/fixtures/`.

## Running Tests

```bash
make test
```
