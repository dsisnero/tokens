# Porting Plan: huggingface/tokenizers → Crystal

**Upstream repo:** https://github.com/huggingface/tokenizers
**Upstream pinned ref:** `3992692` (main branch)
**Vendor path:** `vendor/tokenizers` (git submodule)
**Core Rust crate:** `vendor/tokenizers/tokenizers/src/`

---

## Phases

### Phase 1 — Core BPE Model [x]

**Rust source files:**
- `models/bpe/model.rs` (1171 lines)
- `models/bpe/trainer.rs` (868 lines)
- `models/bpe/word.rs` (353 lines)
- `models/bpe/serialization.rs` (238 lines)
- `models/bpe/mod.rs` (82 lines)

**Crystal target:** `src/tokens/models/bpe/`

Single-file module split into:
- `bpe.cr` — entry point, requires submodules
- `bpe/types.cr` — Pair, Vocab, MergeMap aliases, AddedToken record
- `bpe/word.cr` — Word with linked-list Symbol, MergeHeap
- `bpe/cache.cr` — BpeCache with atomic-style fresh/clear/get/set
- `bpe/iterators.cr` — FirstLastIterator
- `bpe/builder.cr` — BpeBuilder (vocab/merges/files/constructor)
- `bpe/model.cr` — BPE class (tokenize, merge_word, serialization, save/load)
- `bpe/trainer.cr` — BpeTrainer, BpeTrainerBuilder, TrainerMerge
- `bpe/error.cr` — TokenizerError hierarchy

**Rust tests ported:** 2 (test_train, bpe_test_max_token_length_direct_assert)
**Crystal specs:** 35 (tokenization, serialization, training)
**Status:** ✅ Complete

---

### Phase 2 — Tokenizer Pipeline [ ]

**Rust source files:**
- `tokenizer/mod.rs` (1789 lines) — TokenizerImpl, TokenizerBuilder, traits (Normalizer, PreTokenizer, Model, PostProcessor, Decoder, Trainer), Encoding, InputSequence, EncodeInput, DecodeStream
- `tokenizer/encoding.rs` (909 lines) — Encoding struct, serialization of encodings, overflow handling
- `tokenizer/added_vocabulary.rs` (1197 lines) — AddedVocabulary, AddedToken management
- `tokenizer/normalizer.rs` (2311 lines) — NormalizedString, OffsetReferential, SplitDelimiterBehavior, normalizer pattern system
- `tokenizer/pre_tokenizer.rs` (364 lines) — PreTokenizedString, splits, offsets
- `tokenizer/pattern.rs` (221 lines) — Pattern trait, regex/string patterns for splitting
- `tokenizer/serialization.rs` (242 lines) — TokenizerImpl deserialization, version compat

**Key types to port:**
- `Tokenizer` / `TokenizerImpl<M, N, PT, PP, D>` — the main pipeline orchestrator
- `TokenizerBuilder` — builder pattern for constructing pipelines
- `Encoding` — output of tokenization (ids, type_ids, tokens, words, offsets, attention_mask, special_tokens_mask, overflowing, sequence_ids)
- `AddedVocabulary` — special token management
- `NormalizedString` — normalized string with offset mapping
- `PreTokenizedString` — pre-tokenized splits with alignment
- `Pattern` / `RegexPattern` / `StringPattern` — split patterns
- `InputSequence` / `EncodeInput` — input types for encode()
- `DecodeStream` — streaming decode

**Key methods:** `encode`, `encode_batch`, `decode`, `decode_batch`, `train`, `train_from_files`, `save`, `from_pretrained`, `add_special_tokens`, `add_tokens`, `token_to_id`, `id_to_token`, `get_vocab`, `get_vocab_size`

**Estimated specs:** 20+
**Risk:** High (large module, complex trait generics)
**Dependencies:** None (no sub-dependencies outside stdlib + BPE)

**Status:** ⬜ Not started

---

### Phase 3 — Normalizers [ ]

**Rust source files:**
- `normalizers/mod.rs` (281 lines) — NormalizerWrapper, normalizer registry, Normalizer trait impls for serde
- `normalizers/bert.rs` (137 lines) — BertNormalizer (lowercase, strip_accents, clean_text, handle_chinese_chars)
- `normalizers/byte_level.rs` (174 lines) — ByteLevel (UTF-8 bytes mapping)
- `normalizers/replace.rs` (157 lines) — Replace (pattern, content)
- `normalizers/strip.rs` (157 lines) — Strip (left, right)
- `normalizers/unicode.rs` (103 lines) — NFC, NFD, NFKC, NFKD
- `normalizers/precompiled.rs` (89 lines) — PrecompiledNormalizer
- `normalizers/prepend.rs` (62 lines) — Prepend (prefix)
- `normalizers/utils.rs` (60 lines) — Sequence

**Key types:** BertNormalizer, ByteLevel, Replace, Strip, NFC/NFD/NFKC/NFKD, Sequence, Prepend, PrecompiledNormalizer

**Estimated specs:** 10+
**Risk:** Low (small files, standard algorithms)
**Crystal stdlib:** `Unicode.nfc?`, `Unicode.nfd?` etc available

**Status:** ⬜ Not started

---

### Phase 4 — Pre-Tokenizers [ ]

**Rust source files:**
- `pre_tokenizers/mod.rs` (332 lines) — PreTokenizerWrapper, registry, serde
- `pre_tokenizers/byte_level.rs` (593 lines) — ByteLevel (bytes-to-chars mapping, special char handling)
- `pre_tokenizers/bert.rs` (82 lines) — BertPreTokenizer
- `pre_tokenizers/metaspace.rs` (370 lines) — Metaspace (replace/escape special tokens)
- `pre_tokenizers/split.rs` (253 lines) — Split pattern-based pre-tokenizer
- `pre_tokenizers/whitespace.rs` (105 lines) — Whitespace / WhitespaceSplit
- `pre_tokenizers/byte_level.rs` handled under byte_level
- `pre_tokenizers/delimiter.rs` (26 lines) — CharDelimiterSplit
- `pre_tokenizers/digits.rs` (102 lines) — Digits (individual/ignore_single)
- `pre_tokenizers/punctuation.rs` (83 lines) — Punctuation
- `pre_tokenizers/sequence.rs` (82 lines) — Sequence of pre-tokenizers
- `pre_tokenizers/fixed_length.rs` (122 lines) — FixedLength pre-tokenizer
- `pre_tokenizers/unicode_scripts/mod.rs` — Unicode scripts dispatch
- `pre_tokenizers/unicode_scripts/scripts.rs` (2095 lines) — Unicode script detection data tables
- `pre_tokenizers/unicode_scripts/pre_tokenizer.rs` (146 lines) — UnicodeScripts pre-tokenizer

**Key types:** ByteLevel, BertPreTokenizer, Metaspace, Split, Whitespace, Digits, Punctuation, Sequence, FixedLength, UnicodeScripts

**Estimated specs:** 15+
**Risk:** Medium (ByteLevel is complex, UnicodeScripts has large data table)
**Note:** Unicode scripts data table (2095 lines) may need to be generated from Unicode data or ported as-is

**Status:** ⬜ Not started

---

### Phase 5 — Decoders [ ]

**Rust source files:**
- `decoders/mod.rs` (233 lines) — DecoderWrapper, registry, serde
- `decoders/bpe.rs` (38 lines) — BPE decoder
- `decoders/byte_fallback.rs` (109 lines) — ByteFallback
- `decoders/ctc.rs` (120 lines) — CTC decoder
- `decoders/fuse.rs` (43 lines) — Fuse decoder
- `decoders/sequence.rs` (55 lines) — Sequence of decoders
- `decoders/strip.rs` (80 lines) — Strip (left, right, start, stop)
- `decoders/wordpiece.rs` (86 lines) — WordPiece decoder

**Key types:** BPE, ByteFallback, CTC, Fuse, Sequence, Strip, WordPiece

**Estimated specs:** 8+
**Risk:** Very Low (small files, straightforward logic)

**Status:** ⬜ Not started

---

### Phase 6 — Post-Processors [ ]

**Rust source files:**
- `processors/mod.rs` (32 lines used for registry+serde of all of these)
- `processors/bert.rs` (277 lines) — BertProcessing (CLS/SEP)
- `processors/roberta.rs` (341 lines) — RobertaProcessing (prepend/append special tokens, trim offsets)
- `processors/template.rs` (1156 lines) — TemplateProcessing (rendered template-based post-processing)
- `processors/sequence.rs` (172 lines) — Sequence of post-processors

**Key types:** BertProcessing, RobertaProcessing, TemplateProcessing, Sequence

**Estimated specs:** 10+
**Risk:** Medium (TemplateProcessing is complex, 1156 lines)
**Note:** TemplateProcessing is the largest non-tokenizer file — involves a custom template engine with token/vocabulary manipulation

**Status:** ⬜ Not started

---

### Phase 7 — Unigram Model [ ]

**Rust source files:**
- `models/unigram/mod.rs` — module structure
- `models/unigram/model.rs` (664 lines) — Unigram model (score-based tokenization with lattice/Viterbi)
- `models/unigram/trainer.rs` (825 lines) — UnigramTrainer (EM training with KUDO/Unigram algorithm)
- `models/unigram/lattice.rs` (691 lines) — Lattice (DAG for tokenization candidates)
- `models/unigram/serialization.rs` (115 lines)
- `models/unigram/trie.rs` (91 lines) — Trie for vocabulary lookup

**Key types:** Unigram, UnigramTrainer, LatticeNode, Lattice, Trie

**Estimated specs:** 10+
**Risk:** Very High (complex algorithm, lattice/Viterbi, EM training)

**Status:** ⬜ Not started

---

### Phase 8 — WordPiece Model [ ]

**Rust source files:**
- `models/wordpiece/mod.rs` (329 lines) — WordPiece model + builder
- `models/wordpiece/trainer.rs` (203 lines) — WordPieceTrainer
- `models/wordpiece/serialization.rs` (151 lines)

**Key types:** WordPiece, WordPieceTrainer

**Estimated specs:** 5+
**Risk:** Low-Medium (simpler than BPE)

**Status:** ⬜ Not started

---

### Phase 9 — WordLevel Model [ ]

**Rust source files:**
- `models/wordlevel/mod.rs` (251 lines) — WordLevel model + builder
- `models/wordlevel/trainer.rs` (182 lines)
- `models/wordlevel/serialization.rs` (127 lines)

**Key types:** WordLevel, WordLevelTrainer

**Estimated specs:** 5+
**Risk:** Very Low (simplest model)

**Status:** ⬜ Not started

---

### Phase 10 — Utilities [ ]

**Rust source files:**
- `utils/mod.rs` (225 lines) — utility re-exports
- `utils/padding.rs` (142 lines) — PaddingParams, PaddingStrategy, pad_encodings
- `utils/truncation.rs` (326 lines) — TruncationParams, TruncationDirection, TruncationStrategy
- `utils/cache.rs` (128 lines) — LRUCache
- `utils/iter.rs` (99 lines) — LinesWithEnding iterator
- `utils/parallelism.rs` (277 lines) — maybe_par_iter, maybe_par_bridge, maybe_par_sort
- `utils/progress.rs` (49 lines) — ProgressFormat enum
- `utils/fancy.rs` (63 lines) — fancy printing
- `utils/from_pretrained.rs` (68 lines) — Hub downloading (requires HTTP feature)
- `utils/onig.rs` (45 lines) — Oniguruma regex wrapper

**Key types:** PaddingParams, PaddingStrategy, TruncationParams, TruncationStrategy, LRUCache, LinesWithEnding, ProgressFormat

**Estimated specs:** 10+
**Risk:** Low-Medium (parallelism is the trickiest; Crystal has `parallel` module though)

**Status:** ⬜ Not started

---

## Progress Summary

| Phase | Component | Est. Lines | Priority | Risk | Status |
|-------|-----------|-----------|----------|------|--------|
| 1 | Core BPE | 3800 | P0 | Medium | ✅ Done |
| 2 | Tokenizer Pipeline | 6900 | P0 | High | ⬜ |
| 3 | Normalizers | 1100 | P1 | Low | ⬜ |
| 4 | Pre-Tokenizers | 4200 | P1 | Medium | ⬜ |
| 5 | Decoders | 700 | P2 | Very Low | ⬜ |
| 6 | Post-Processors | 2000 | P2 | Medium | ⬜ |
| 7 | Unigram Model | 2400 | P2 | Very High | ⬜ |
| 8 | WordPiece Model | 700 | P3 | Low-Medium | ⬜ |
| 9 | WordLevel Model | 600 | P3 | Very Low | ⬜ |
| 10 | Utilities | 1450 | P1 | Low-Medium | ⬜ |

**Total Rust source:** ~24,000 lines across ~68 files
**Phases completed:** 1 of 10

## Architecture

The Rust crate's module hierarchy maps directly to Crystal:

```
src/tokens.cr                    # Entry: requires all modules
├── src/tokens/model.cr          # Model trait (abstract module)
├── src/tokens/token.cr          # Token record
├── src/tokens/extensions.cr     # Hash#drain extension
├── src/tokens/models/
│   ├── bpe/                     # Phase 1 (done)
│   ├── unigram/                 # Phase 7
│   ├── wordpiece/               # Phase 8
│   └── wordlevel/               # Phase 9
├── src/tokens/tokenizer/        # Phase 2
├── src/tokens/normalizers/      # Phase 3
├── src/tokens/pre_tokenizers/   # Phase 4
├── src/tokens/decoders/         # Phase 5
├── src/tokens/processors/       # Phase 6
└── src/tokens/utils/            # Phase 10
```

Each phase follows the same pattern established by Phase 1:
1. Translate Rust source to Crystal preserving exact behavior
2. Port relevant Rust tests as Crystal specs
3. Run quality gates (`crystal tool format --check`, `ameba`, `crystal spec`)
4. Update rust_test_parity.tsv

## Design Decisions

- No `mod.cr` files — Crystal convention uses directory name as module name, entry file at directory level
- Crystal stdlib only for ported code (no external shards)
- `AddedToken` defined as a Crystal `record` within each model module
- Serialization uses `JSON.build` / `JSON.parse` (Crystal stdlib)
- Parallelism: Crystal has `parallel` module in stdlib for some use cases; `maybe_par_iter` patterns from Rust use `Channel` or `Fiber` equivalents where available
- Unicode normalization: Crystal stdlib has `Unicode.nfc?`, `Unicode.nfd?`, etc.
- Regex: Crystal uses PCRE2 (different from Rust's regex crate) — patterns may need adjustment
