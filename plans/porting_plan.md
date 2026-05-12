# Porting Plan: `huggingface/tokenizers` -> Crystal

**Upstream repo:** https://github.com/huggingface/tokenizers
**Upstream pinned ref:** `3992692`
**Vendor path:** `vendor/tokenizers`
**Core Rust crate:** `vendor/tokenizers/tokenizers/src/`

This plan is inventory-driven. It should be updated from:

- `plans/inventory/rust_port_inventory.tsv`
- `plans/inventory/rust_test_parity.tsv`

## Current Status (2026-05-11)

**Active feature:** `Feature 10 — Fancy diagnostics` (final optional utility)

**Overall:** SUBSTANTIALLY COMPLETE. All runtime pipeline, models, utilities, and integration tests ported. 299 specs passing, 0 pending, 0 missing test parity.

### What's done

| Area | Source | Tests | Status |
|---|---|---|---|
| Tokenizer core | 145 reconciled | 29 ported | Done |
| Normalizers | 30 ported | 14 ported | Done |
| Pre-tokenizers | 50 ported | 41 ported | Done |
| Decoders | 29 ported | 12 ported | Done |
| Post-processors | 41 ported | 18 ported | Done |
| BPE model | 68 reconciled | covered | Done |
| WordLevel | 22 ported | 6 ported | Done |
| WordPiece | 43 ported | 3 ported | Done |
| Unigram | 66 ported | 20 ported | Done |
| Model wrapper | 12 ported | 3 ported | Done |
| Serialization matrix | — | 12 ported | Done |
| Documentation tests | — | 8 ported | Done |
| Training tests | — | 2 ported | Done |
| from_pretrained utility | 4 ported | 4 ported | Done |
| Wiki training tests | — | 2 ported | Done |
| Parallelism utility | 4 ported | 2 ported | Done |
| Progress utility | 15 ported | — | Done |
| Iterator utilities | 3 ported | — | Done |

**Quality gates:** 299 specs pass, 0 failures, 0 pending. Format check clean. Ameba residual backlog tracked.

**Parity inventory:**
- Port inventory: 702 ported, 2 partial, 53 skipped (intentional divergences), 0 missing
- Source parity: 515 API items tracked, 0 missing
- Test parity: 241 ported, 1 partial (Unigram esaxx), 0 missing
- Adversarial verification: PASSED

## Feature 1 - Runtime Pipeline Parity

**Status:** COMPLETE. All stages, wrappers, and serialization ported and tested.

### 1.1 Tokenizer core
- [x] All tokenizer infrastructure ported (Encoding, NormalizedString, PreTokenizedString, AddedVocabulary, pattern, truncation, padding, serialization)

### 1.2 Normalizers
- [x] All 10 normalizer types ported, NormalizerWrapper with tagged/untagged JSON

### 1.3 Pre-tokenizers
- [x] All 11 pre-tokenizer types ported, PreTokenizerWrapper with tagged JSON

### 1.4 Decoders
- [x] All 8 decoder types ported, DecoderWrapper with tagged JSON

### 1.5 Post-processors
- [x] All 4 post-processor types ported, PostProcessorWrapper with tagged/untagged JSON

### 1.6 Runtime integration tests
- [x] Tokenizer serialization round-trip, offsets, added_tokens, stream, documentation (8 tests), training (2 tests), from_pretrained (4 tests), wiki training (2 tests)

## Feature 2 - Additional Model Families

**Status:** COMPLETE.

### 2.1 WordLevel
- [x] Model, trainer, serialization, 6 specs

### 2.2 WordPiece
- [x] Greedy longest-match tokenizer, WordPieceTrainer (delegates to BpeTrainer), serialization, 11 specs

### 2.3 Unigram
- [x] Trie, Viterbi lattice (viterbi/nbest/populate_marginal), EM trainer (digamma, e-step, m-step, pruning, finalize), serialization, 30 specs

### 2.4 Model wrapper
- [x] ModelWrapper (tagged/untagged JSON), TrainerWrapper, cross-model serialization, 9 specs

## Feature 3 - Integration, Serialization, and Distribution

**Status:** COMPLETE. All integration tests ported, serialization validated, utilities ported.

### 3.1 Serialization
- [x] Cross-model round-trips, wrapper ↔ inner type JSON, all components to_json/from_json

### 3.2 Core utilities
- [x] `train_from_files` — train BPE/WordPiece from text files
- [x] `encode_batch` — batch encoding with BatchLongest padding
- [x] `from_pretrained` — HTTP download from HuggingFace Hub with caching

### 3.3 Utility layer
- [x] `parallelism` — sequential wrapper with upstream API surface
- [x] `iter` — LinesWithEnding (preserves `\n`/`\r`), ResultShunt (n/a in Crystal)
- [x] `progress` — ProgressBar, ProgressStyle, ProgressFormat
- [x] `onig` — resolved via PCRE2 SysRegex wrapper

### 3.4 Bug fixes
- [x] `SysRegex#find_iter` PCRE multi-byte UTF-8 bug (unblocked 3 documentation tests)
- [x] `encode_batch` batch-level padding (unblocked quicktour padding assertions)

## Remaining Work

### Only actionable item

**Feature 10 — Fancy Diagnostics** (`src/utils/fancy.rs`):
- Pretty-print diagnostics for regex patterns with `Matches` iterator
- 3 source items (func::new, struct::Matches, struct::SysRegex)
- Not needed for core functionality; would complete the utility layer

### Known partials (not blocking)

| Item | Status | Notes |
|---|---|---|
| Unigram `test_train_unigram_from_file` | partial | Vocab size differs — esaxx suffix arrays not ported; n-gram seed generation produces different count |
| Intentional divergences | 53 skipped | Crystal idioms (exceptions vs Result, method chaining vs builder, explicit JSON vs serde, PCRE2 vs Oniguruma) |

### Out of scope

| Area | Reason |
|---|---|
| `bindings/` (Node, Python) | Outside Crystal scope |
| `examples/unstable_wasm/` | WASM not applicable to Crystal CLI |
| `benches/` | Require large data files; not ported |
