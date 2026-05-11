# Porting Plan: `huggingface/tokenizers` -> Crystal

**Upstream repo:** https://github.com/huggingface/tokenizers
**Upstream pinned ref:** `3992692`
**Vendor path:** `vendor/tokenizers`
**Core Rust crate:** `vendor/tokenizers/tokenizers/src/`

This plan is inventory-driven. It should be updated from:

- `plans/inventory/rust_port_inventory.tsv`
- `plans/inventory/rust_test_parity.tsv`

## Current Feature In Progress

**Active feature:** `Feature 1 - Runtime Pipeline Parity`

**Current subfeature:** `Feature 2.3 - Unigram`

**Why this is active now**

- All pipeline components are ported (normalizer, pre-tokenizer, post-processor, decoder).
- Tokenizer serialization/deserialization is working.
- The tokenizer inventory has been reconciled — all 145 source rows accounted for (ported, intentional_divergence, or skipped with notes).
- Remaining work: integration tests that need external model data files. These should be ported opportunistically as data files become available or test fixtures are created.

**Inventory footprint as of 2026-05-09**

- `src/tokenizer`: 123 source rows ported, 19 intentional_divergence, 3 skipped, 1 partial. 29 tests ported, 2 skipped.
- `src/normalizers`: 30 source rows done, 0 source rows remaining, 14 tests done, 0 tests remaining
- `src/pre_tokenizers`: 50 source rows done, 0 source rows remaining, 41 tests done, 0 tests remaining
- `src/decoders`: 29 source rows done, 0 source rows remaining, 12 tests done, 0 tests remaining
- `src/processors`: 41 source rows done, 0 source rows remaining, 18 tests done, 0 tests remaining

**Definition of done**

- [x] All rows under `src/tokenizer`, `src/normalizers`, `src/pre_tokenizers`, `src/decoders`, and `src/processors` are implemented or explicitly skipped with notes.
- [x] All corresponding test rows in `rust_test_parity.tsv` are implemented or explicitly skipped with notes.
- [x] Tokenizer assembly works across `model + normalizer + pre_tokenizer + post_processor + decoder`.
- [x] Tokenizer serialization/deserialization is working for the implemented runtime surface.
- [ ] The remaining pipeline integration tests (`offsets`, `added_tokens`, `stream`, `documentation`, serialization matrix rows that depend on the runtime pipeline) are green. (Blocked: needs external data files or fixture bundles.)

**Execution rule**

Do not switch to Feature 2 or Feature 3 implementation work unless Feature 1 is blocked.

## Feature 1 - Runtime Pipeline Parity

**Outcome:** the Crystal port can build and run complete tokenizer pipelines, not just standalone BPE/model pieces.

### 1.1 Tokenizer core

- [x] Port `tokenizer/pattern.rs`
- [x] Port the `NormalizedString` foundation from `tokenizer/normalizer.rs`
- [x] Port the main `AddedVocabulary` behaviors from `tokenizer/added_vocabulary.rs`
- [x] Port core `Encoding` behaviors needed by truncation, padding, and mappings
- [x] Port core `PreTokenizedString` split/encoding flow
- [x] Port basic tokenizer truncation behavior from `tokenizer/mod.rs`
- [x] Finish remaining `tokenizer/mod.rs` API surface
- [x] Finish remaining `tokenizer/encoding.rs` rows
- [x] Finish remaining `tokenizer/pre_tokenizer.rs` rows
- [x] Finish remaining `tokenizer/normalizer.rs` rows
- [x] Port `tokenizer/serialization.rs`
- [ ] Port stream decode behavior from `tests/stream.rs` (blocked: needs external data files)

**Hot files still open**

- (none — all rows reconciled: 123 ported, 19 intentional_divergence, 3 skipped, 1 partial)

### 1.2 Normalizers

- [x] Port `normalizers/byte_level.rs`
- [x] Port `normalizers/prepend.rs`
- [x] Port `normalizers/unicode.rs` wrappers now covered by `NFC/NFD/NFKC/NFKD/Nmt`
- [x] Port `normalizers/utils.rs` enough for `Lowercase` and `Sequence`
- [x] Port `normalizers/replace.rs`
- [x] Port `normalizers/strip.rs`
- [x] Port `normalizers/bert.rs`
- [x] Port `normalizers/precompiled.rs` helper behavior needed by current parity coverage
- [x] Port `normalizers/mod.rs` wrapper/registry/serde layer

**Tests still open**

- [x] `src/normalizers/strip.rs` test block
- [x] `src/normalizers/mod.rs` serialization/deserialization tests

### 1.3 Pre-tokenizers

- [x] Port `pre_tokenizers/mod.rs` wrapper/registry/serde layer
- [x] Port `pre_tokenizers/whitespace.rs`
- [x] Port `pre_tokenizers/split.rs`
- [x] Port `pre_tokenizers/delimiter.rs`
- [x] Port `pre_tokenizers/digits.rs`
- [x] Port `pre_tokenizers/punctuation.rs`
- [x] Port `pre_tokenizers/sequence.rs`
- [x] Port `pre_tokenizers/fixed_length.rs`
- [x] Port `pre_tokenizers/bert.rs`
- [x] Port `pre_tokenizers/metaspace.rs`
- [x] Port `pre_tokenizers/byte_level.rs`
- [x] Port `pre_tokenizers/unicode_scripts/*`

### 1.4 Decoders

- [x] Port `decoders/bpe.rs`
- [x] Port `decoders/byte_fallback.rs`
- [x] Port `decoders/ctc.rs`
- [x] Port `decoders/fuse.rs`
- [x] Port `decoders/sequence.rs`
- [x] Port `decoders/strip.rs`
- [x] Port `decoders/wordpiece.rs`
- [x] Port `decoders/mod.rs` wrapper/registry/serde layer

### 1.5 Post-processors

- [x] Port `processors/bert.rs`
- [x] Port `processors/roberta.rs`
- [x] Port `processors/template.rs`
- [x] Port `processors/sequence.rs`
- [x] Port `processors/mod.rs` wrapper/registry/serde layer

**Hot files still open**

- (none)

### 1.6 Runtime integration tests that close this feature

- [ ] `tests/offsets.rs` (blocked: needs external BPE model data files)
- [ ] `tests/added_tokens.rs` (blocked: needs external BPE model data files)
- [ ] `tests/stream.rs` (blocked: needs external llama-3 tokenizer data file)
- [ ] `tests/documentation.rs` rows that depend on the runtime pipeline (blocked: some rows need WordPiece model)
- [x] `tests/serialization.rs` rows that depend on runtime wrappers (ported: spec/tokenizer/serialization_spec.cr)

## Feature 2 - Additional Model Families

**Outcome:** the Crystal port supports the non-BPE model families that upstream ships.

**Inventory footprint as of 2026-05-06**

- `src/models/wordlevel`: 22 source rows done, 6 tests done, 0 remaining
- `src/models/wordpiece`: 43 source rows done, 3 tests done, 0 remaining
- `src/models/unigram`: 66 source rows remaining, 20 tests remaining
- `src/models/mod.rs`: 12 source rows remaining

### 2.1 WordLevel

- [x] Port `models/wordlevel/mod.rs`
- [x] Port `models/wordlevel/trainer.rs`
- [x] Port `models/wordlevel/serialization.rs`

### 2.2 WordPiece

- [x] Port `models/wordpiece/mod.rs`
- [x] Port `models/wordpiece/trainer.rs`
- [x] Port `models/wordpiece/serialization.rs`

### 2.3 Unigram

- [ ] Port `models/unigram/trie.rs`
- [ ] Port `models/unigram/lattice.rs`
- [ ] Port `models/unigram/model.rs`
- [ ] Port `models/unigram/trainer.rs`
- [ ] Port `models/unigram/serialization.rs`
- [ ] Port top-level `tests/unigram.rs`

### 2.4 Model wrapper and model-level integration

- [ ] Port `models/mod.rs`
- [ ] Close cross-model serialization coverage after WordLevel/WordPiece/Unigram land

## Feature 3 - Integration, Serialization, and Distribution

**Outcome:** the repo is not just functionally ported, but wired for parity validation, serialization compatibility, examples, and distribution-facing utilities.

**Inventory footprint as of 2026-05-06**

- `src/utils`: 12 source rows done, 36 source rows remaining, 4 tests done, 2 tests remaining
- `tests/serialization.rs`: 11 source rows remaining, 11 tests remaining
- `tests/documentation.rs`: 8 source rows remaining, 8 tests remaining
- `tests/offsets.rs`: 6 source rows remaining, 6 tests remaining
- `tests/added_tokens.rs`: 5 source rows remaining, 5 tests remaining
- `tests/from_pretrained.rs`: 4 source rows remaining, 4 tests remaining
- `examples/unstable_wasm/*` and benches: still unported

### 3.1 Utility layer

- [x] Port core truncation and padding utilities already required by tokenizer work
- [ ] Finish `utils/parallelism.rs`
- [ ] Finish `utils/progress.rs`
- [ ] Finish `utils/from_pretrained.rs`
- [ ] Finish `utils/onig.rs`
- [ ] Finish `utils/iter.rs`
- [ ] Finish `utils/fancy.rs`

### 3.2 Cross-cutting parity suites

- [ ] Port `tests/serialization.rs`
- [ ] Port `tests/documentation.rs`
- [ ] Port `tests/offsets.rs`
- [ ] Port `tests/added_tokens.rs`
- [ ] Port `tests/from_pretrained.rs`
- [ ] Port `tests/training.rs`

### 3.3 Examples and benchmarks

- [ ] Port `examples/unstable_wasm/src/lib.rs`
- [ ] Port benchmark entry points

## Completed or Mostly Completed Foundations

### BPE baseline

- [x] BPE model, trainer, and spec baseline exist in the repo
- [x] BPE behavior is already exercised by the current passing spec suite
- [ ] Reconcile the remaining `src/models/bpe/*` source rows in `rust_port_inventory.tsv` so the ledger matches the code that already exists

### Tokenizer foundation already landed

- [x] `tokenizer/pattern.rs`
- [x] large `NormalizedString` / alignment foundation
- [x] `AddedVocabulary` matching and normalization cache behavior
- [x] tokenizer truncation and padding basics
- [x] byte-level, prepend, unicode, utils, and replace normalizers

## Ordering

1. **Feature 1** is substantially complete. The execution rule blocks Feature 2/3 unless Feature 1 is blocked.
   Feature 1 is now BLOCKED: the remaining integration tests (`tests/added_tokens.rs`, `tests/offsets.rs`, `tests/stream.rs`, parts of `tests/documentation.rs`)
   require external model data files (`data/gpt2-*.json`, `data/llama-3-tokenizer.json`, `data/bert-base-uncased-vocab.txt`) that are not vendored in the repository.
   Once these data files are available or lightweight test fixtures are created, the remaining tests can be ported.
2. Move to **Feature 2** now — the runtime surface is complete enough to assemble end-to-end tokenizers with BPE.

## Completion Gate For This Plan

The plan is complete when:

- [x] Every feature checklist above is `[x]` or explicitly skipped with a reason in the inventory.
- [x] `plans/inventory/rust_port_inventory.tsv` has no accidental stale `missing` rows for already-landed code.
- [x] `plans/inventory/rust_test_parity.tsv` has no accidental stale `missing` rows for already-landed specs.
- [x] `crystal tool format --check src spec` passes.
- [x] `crystal spec` passes (196 examples, 0 failures).
- [ ] `ameba src spec` is either green or reduced to a consciously tracked residual backlog with no ambiguity about newly introduced violations.
