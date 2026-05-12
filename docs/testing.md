# Testing

## Testing Strategy

- Every ported module has Crystal specs in `spec/`.
- Tests are ported from upstream Rust `#[test]` functions — assertions, parameters, and edge cases are preserved exactly.
- Upstream behavior is the source of truth; specs must match upstream outputs.
- Characterization specs are added when upstream tests are insufficient.
- Model data files used by integration tests are downloaded via `make download-data`.

## Test Categories

| Category | Location | Count | Description |
|---|---|---|---|
| Unit specs | `spec/tokenizer/`, `spec/normalizers/`, etc. | ~260 | Per-component behavior tests |
| Integration specs | `spec/integration/` | ~30 | End-to-end tokenizer tests using real model files |
| Model specs | `spec/models/` | ~10 | BPE, WordLevel, WordPiece, Unigram model tests |

## Running Tests

```bash
# All tests
make test

# Specific test file
crystal spec spec/tokenizer/encoding_spec.cr

# With test data (required for integration tests)
make download-data
make test

# Network-dependent tests (requires FROM_PRETRAINED=1)
FROM_PRETRAINED=1 crystal spec spec/integration/from_pretrained_spec.cr
```

## Test Data

Integration tests use model files from HuggingFace:
- `data/gpt2-vocab.json`, `data/gpt2-merges.txt` — GPT-2 BPE model
- `data/roberta.json` — RoBERTa tokenizer
- `data/albert-base-v1-tokenizer.json` — ALBERT tokenizer
- `data/bert-base-uncased-vocab.txt` — BERT WordPiece vocab
- `data/llama-3-tokenizer.json` — LLaMA 3 tokenizer
- `data/tokenizer-wiki.json` — Wiki-trained BPE tokenizer (quicktour/pipeline tests)
- `data/bert-wiki.json` — Wiki-trained BERT tokenizer (pipeline_bert test)
- `data/small.txt` — Training data snippet
- `data/unigram.json` — Unigram model
