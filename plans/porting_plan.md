# Porting Plan: `huggingface/tokenizers` -> Crystal

**Upstream repo:** https://github.com/huggingface/tokenizers
**Upstream pinned ref:** `3992692`
**Vendor path:** `vendor/tokenizers`
**Core Rust crate:** `vendor/tokenizers/tokenizers/src/`

This plan is inventory-driven. It should be updated from:

- `plans/inventory/rust_port_inventory.tsv`
- `plans/inventory/rust_test_parity.tsv`

## Current Status (2026-05-11)

**Active feature:** `Feature 4 — from_pretrained utility`

**Current subfeature:** `Feature 4.1 — Port utils/from_pretrained.rs`

### What's done

All runtime pipeline components and model families are ported and inventory validated:

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
| Documentation tests | — | 8 ported | Done |
| Training tests | — | 2 ported | Done |

**Quality gates:** 291 specs pass, 0 failures, 0 pending. Format check clean. Ameba residual backlog tracked.

**Parity inventory:** validated and passing all drift checks.
- Port inventory: 757 items tracked (ported/partial/skipped), 0 missing
- Source parity: 515 API items tracked, 0 missing
- Test parity: 242 tests tracked, 0 missing
- Adversarial verification: PASSED

**Inventory scripts:** synced from `cross-language-crystal-parity` skill directory.

### Fixes applied (2026-05-11)

- `src/tokens/tokenizer/pattern.cr` — `SysRegex#find_iter` switched from `Regex.match(str, pos)` to `String#scan(regex)`. Crystal's PCRE `Regex.match` has a bug where matches fail at positions following multi-byte UTF-8 characters (e.g., after emoji). This resolved 3 pending documentation tests.
- `src/tokens/tokenizer/tokenizer.cr` — `encode_batch` now applies batch-level `pad_encodings` after individual encodes, matching upstream behavior.
- `src/tokens/tokenizer/tokenizer.cr` — Added `train_from_files` and `encode_batch` methods.
- `src/tokens/models/bpe/trainer.cr` — Added `include Trainer(BPE)` and `train(model : BPE)` method.

### Remaining work — organized as features

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

## Feature 4 — from_pretrained Utility

**Status:** IN PROGRESS.

### 4.1 Port `src/utils/from_pretrained.rs`

Upstream file: `vendor/tokenizers/tokenizers/src/utils/from_pretrained.rs`
Depends on: HTTP client (Crystal's `HTTP::Client`), JSON parsing

What it does:
- Downloads tokenizer JSON files from HuggingFace Hub API
- Supports model revision pinning
- Handles auth tokens (optional)
- Caches downloaded files locally

### 4.2 Port `tests/from_pretrained.rs` (4 tests)

| Test | What it validates | Data needed |
|---|---|---|
| `test_from_pretrained` | Downloads a real tokenizer from HF Hub | Network access, HF Hub |
| `test_from_pretrained_invalid_model` | Rejects non-existent model IDs | Network access |
| `test_from_pretrained_invalid_revision` | Rejects invalid revisions | Network access |
| `test_from_pretrained_revision` | Downloads with specific revision | Network access |

## Feature 5 — Wiki Training Tests

**Status:** PENDING (blocked on wiki data download).

### 5.1 Add wiki data to `make download-data`

Upstream `#[ignore]` tests train on `data/wikitext-103-raw/wiki.{train,test,valid}.raw` (~500MB). These files may be available from HuggingFace test data. Add download targets.

### 5.2 Port `tests/documentation.rs::quicktour_slow_train`

Trains a BPE tokenizer on wiki data, saves to `data/tokenizer-wiki.json`. This is the canonical training flow from the upstream quicktour documentation.

### 5.3 Port `tests/documentation.rs::train_pipeline_bert`

Trains a WordPiece tokenizer on wiki data with BERT normalizer/pre-tokenizer/processor configuration. Saves to `data/bert-wiki.json`.

## Feature 6 — Parallelism Utility

**Status:** PENDING.

### 6.1 Port `src/utils/parallelism.rs`

Upstream uses Rayon for parallel iterators. Crystal equivalent: simple sequential wrapper or `Channel`-based parallelism. The upstream tests validate the `maybe_par_iter`/`maybe_par_bridge` adapter patterns.

### 6.2 Port 2 parallelism tests

| Test | What it validates |
|---|---|
| `test_maybe_parallel_iterator` | Parallel iterator adapter over `Vec` |
| `test_maybe_parallel_slice` | Parallel slice adapter |

## Feature 7 — Progress Utility (Optional)

**Status:** PENDING (optional).

### 7.1 Port `src/utils/progress.rs`

No Crystal equivalent of `indicatif` progress bars. Could implement a simple callback-based progress reporter or use Crystal's `Progress` from stdlib. Not needed for functionality but would complete the utility layer.

## Feature 8 — Iterator Utilities (Optional)

**Status:** PENDING (optional).

### 8.1 Port `src/utils/iter.rs`

Rust iterator adapters (`LinesWithEnding`, `ResultShunt`). Crystal equivalents exist in `Iterator` stdlib. Porting would provide the exact upstream semantics for line-by-line file reading with preserved line endings.

## Feature 9 — Oniguruma Regex (Optional)

**Status:** RESOLVED — Crystal uses PCRE2 via `SysRegex` wrapper (already ported). The upstream `onig.rs` wraps Oniguruma regex; our `SysRegex` wraps PCRE2 with equivalent functionality.

## Feature 10 — Fancy Diagnostics (Optional)

**Status:** PENDING (optional).

### 10.1 Port `src/utils/fancy.rs`

Pretty-print diagnostics for regex patterns with `Matches` iterator. Not needed for core functionality but would complete the utility layer.

## Ordering

Priority by impact:
1. **Feature 4** — `from_pretrained` utility + 4 tests. Unblocks downloading models from HF Hub.
2. **Feature 5** — Wiki training tests (2 tests, currently `#[ignore]` in upstream). Unblocks the full training documentation.
3. **Feature 6** — Parallelism utility + 2 tests. Simple port (sequential wrapper).
4. **Features 7-10** — Optional utilities (progress, iter, onig, fancy). Lower priority.
