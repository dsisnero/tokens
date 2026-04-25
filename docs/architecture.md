# docs/architecture.md

## Architecture

This is a Crystal port of the Rust `tokenizers` crate from huggingface/tokenizers.

The upstream is organized as:

```
tokenizers/src/
  lib.rs              # Crate root, module declarations
  models/             # Tokenizer models (BPE, WordPiece, Unigram)
  tokenizer.rs        # Core Tokenizer struct
  pre_tokenizers/     # Pre-tokenization strategies
  normalizers/        # Normalization strategies
  processors/         # Post-processing
  decoders/           # Decoding strategies
  trainers/           # Model trainers
  utils/              # Utilities
```

The Crystal port mirrors this structure under `src/tokens/`.
