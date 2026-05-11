# Porting Plan: `huggingface/tokenizers` -> Crystal

**Upstream repo:** https://github.com/huggingface/tokenizers
**Upstream pinned ref:** `3992692`
**Vendor path:** `vendor/tokenizers`
**Core Rust crate:** `vendor/tokenizers/tokenizers/src/`

This plan is inventory-driven. It should be updated from:

- `plans/inventory/rust_port_inventory.tsv`
- `plans/inventory/rust_test_parity.tsv`

## Current Status (2026-05-09)

**Active feature:** `Feature 3 - Integration, Serialization, and Distribution`

**Current subfeature:** `Feature 3.2 - Inventory reconciliation`

### What's done

All runtime pipeline components and model families are ported:

| Area | Source | Tests | Status |
|---|---|---|---|
| Tokenizer core | 145 reconciled (0 missing) | 29 ported | Done |
| Normalizers | 30 ported | 14 ported | Done |
| Pre-tokenizers | 50 ported | 41 ported | Done |
| Decoders | 29 ported | 12 ported | Done |
| Post-processors | 41 ported | 18 ported | Done |
| BPE model | 68 reconciled (0 missing) | covered | Done |
| WordLevel | 22 ported | 6 ported | Done |
| WordPiece | 43 ported | 3 ported | Done |
| Unigram | 66 ported | 20 ported | Done |
| Model wrapper | 12 ported | 3 ported | Done |
| Serialization matrix | — | 12 ported | Done |

**Quality gates:** 267 specs pass, format check clean, ameba residual backlog tracked.

### What's actionable next

Only two categories of work remain:

1. **`tests/unigram.rs`** — end-to-end Unigram integration test (3 test functions, portable since Unigram model and trainer are fully implemented). This is the highest-value remaining feature work.

2. **Inventory reconciliation** — 99 source rows and 49 test rows marked `missing` in manifests. These are NOT code gaps — they're inventory ledger gaps. The actual code exists but the manifests weren't updated. Most are:
   - `tests/*` rows (serialization.rs, documentation.rs, offsets.rs, added_tokens.rs, training.rs, from_pretrained.rs, stream.rs) — all blocked on external data files
   - `src/utils/*` rows (parallelism, progress, fancy, iter, onig, from_pretrained) — intentionally skipped (Crystal idioms differ, no equivalent libraries)
   - `src/models/mod.rs` (12 rows) — TrainerWrapper inventory needs reconciliation
   - `examples/`, `benches/` — intentionally skipped (WASM, benchmarks not needed)

### What's blocked (cannot be done without data files)

These upstream integration tests need external model data files not vendored in the repo:

| Test file | Needed data | Tests |
|---|---|---|
| `tests/added_tokens.rs` | `data/gpt2-vocab.json`, `data/gpt2-merges.txt` | 5 |
| `tests/offsets.rs` | `data/gpt2-*` BPE files | 6 |
| `tests/stream.rs` | `data/llama-3-tokenizer.json` | 2 |
| `tests/documentation.rs` | WordPiece `data/bert-base-uncased-vocab.txt` | 8 |
| `tests/from_pretrained.rs` | HTTP + pretrained model files | 4 |
| `tests/training.rs` | Training data files | 2 |
| `tests/serialization.rs` (remaining) | `data/gpt2-*`, `data/albert-base-v1-tokenizer.json` | 11 |
| `tests/common/mod.rs` | Test helper infrastructure | 5 |

**Resolution:** either vend the data files as test fixtures, or create lightweight synthetic fixtures that exercise the same code paths.

## Feature 1 - Runtime Pipeline Parity

**Status:** SUBSTANTIALLY COMPLETE. Blocked only on integration tests needing external data.

### 1.1 Tokenizer core

- [x] All tokenizer infrastructure ported (Encoding, NormalizedString, PreTokenizedString, AddedVocabulary, pattern, truncation, padding, serialization)
- [x] Inventory fully reconciled

### 1.2 Normalizers

- [x] All normalizer types ported (NFC/NFD/NFKC/NFKD/Nmt, Lowercase, Strip/StripAccents, Replace, Prepend, BertNormalizer, ByteLevel, Precompiled, Sequence)
- [x] NormalizerWrapper with tagged JSON

### 1.3 Pre-tokenizers

- [x] All pre-tokenizer types ported (Whitespace, ByteLevel, Metaspace, Digits, Punctuation, Split, Delimiter, FixedLength, BertPreTokenizer, UnicodeScripts, Sequence)
- [x] PreTokenizerWrapper with tagged JSON

### 1.4 Decoders

- [x] All decoder types ported (BPE, ByteLevel, ByteFallback, CTC, Fuse, Strip, WordPiece, Metaspace, Sequence)
- [x] DecoderWrapper with tagged JSON

### 1.5 Post-processors

- [x] All post-processor types ported (BertProcessing, RobertaProcessing, TemplateProcessing, Sequence)
- [x] PostProcessorWrapper with tagged/untagged JSON

### 1.6 Runtime integration tests

- [x] Tokenizer serialization round-trip (spec/tokenizer/serialization_spec.cr)
- [ ] Remaining tests blocked on external data files (see above)

## Feature 2 - Additional Model Families

**Status:** COMPLETE. All three model families ported with trainers.

### 2.1 WordLevel
- [x] Model, trainer, serializer, serialization, 6 specs

### 2.2 WordPiece
- [x] Greedy longest-match tokenizer, BpeTrainer delegating trainer, serialization, 11 specs

### 2.3 Unigram
- [x] Trie, Viterbi lattice (viterbi/nbest/populate_marginal), EM trainer (digamma, e-step, m-step, pruning, finalize), serialization, 30 specs

### 2.4 Model wrapper
- [x] ModelWrapper (tagged/untagged JSON), TrainerWrapper (type-checked train), cross-model tokenizer serialization, 9 specs

## Feature 3 - Integration, Serialization, and Distribution

**Status:** IN PROGRESS.

### 3.1 Serialization matrix

- [x] Port `tests/serialization.rs` inner-type ↔ wrapper round-trips (12 tests)
- [x] Added `to_json` to NormalizerWrapper, PreTokenizerWrapper, and 8 inner types (NFC/NFD/NFKC/NFKD/Nmt, BertNormalizer, BertPreTokenizer, Whitespace)
- [ ] Remaining serialization tests blocked on `data/` files

### 3.2 Inventory reconciliation

- [x] BPE inventory reconciled (0 missing)
- [ ] `tests/*` rows — mark as `blocked` (needs data files)
- [ ] `src/utils/*` rows — mark as `intentional_divergence` (Crystal equivalents differ)
- [ ] `src/models/mod.rs` (12 rows) — reconcile TrainerWrapper
- [ ] `examples/` and `benches/` — mark as `skipped`

### 3.3 End-to-end Unigram integration test

- [ ] Port `tests/unigram.rs` (3 test functions). Unigram model and trainer are fully ported — this test validates them working together.

### 3.4 Utility layer

- [x] Core truncation and padding utilities (needed by tokenizer)
- [ ] Remaining utilities not ported:
  - `utils/parallelism.rs` — Rayon threading (Crystal: fibers, not needed yet)
  - `utils/progress.rs` — indicatif progress bar (no Crystal equivalent)
  - `utils/from_pretrained.rs` — HTTP model download (not needed yet)
  - `utils/onig.rs` — Oniguruma regex (Crystal: PCRE2 via SysRegex)
  - `utils/iter.rs` — Rust iterator adapters (Crystal uses different patterns)
  - `utils/fancy.rs` — Pretty-print diagnostics (not needed yet)

### 3.5 Examples and benchmarks

- [ ] `examples/unstable_wasm/` — skip (WASM not applicable to Crystal CLI)
- [ ] `benches/` — skip for now (benchmarks need data files)

## Ordering

The only remaining feature work is `tests/unigram.rs`. Everything else is either:
- Blocked on external data files (integration tests)
- Inventory reconciliation (marking already-decided statuses)
- Intentionally skipped (utilities, examples, benches)

Priority:
1. Port `tests/unigram.rs` — validates Unigram end-to-end
2. Reconcile remaining inventory (99 source + 49 test rows → mark as blocked/skipped/divergence)
3. Create lightweight test fixtures to unblock integration tests (or vend data files)

## Completion Gate

- [x] All runtime pipeline components ported (Feature 1)
- [x] All model families ported (Feature 2)
- [x] Cross-model serialization working
- [x] `crystal tool format --check src spec` passes
- [x] `crystal spec` passes (267 examples)
- [ ] Inventory fully reconciled (0 genuine `missing` rows)
- [ ] `tests/unigram.rs` ported
- [ ] Integration tests unblocked (data files vendored or fixtures created)
