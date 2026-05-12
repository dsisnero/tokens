# Architecture

This document describes the architecture of the Crystal port of [huggingface/tokenizers](https://github.com/huggingface/tokenizers), pinned at upstream ref `3992692`.

## Directory Layout

```
src/
  tokens.cr                    # Main entry point (require "tokens")
  tokens/
    token.cr                   # Token value type (id, value, offsets)
    model.cr                   # Abstract Model module + TokenizerError
    extensions.cr              # Hash extensions

    tokenizer/                 # Core tokenizer infrastructure
      encoding.cr              # Encoding struct + Truncation/Padding types
      truncation.cr            # truncate_encodings helper
      tokenizer.cr             # TokenizerImpl, Tokenizer, DecodeStream, abstract modules
      normalizer.cr            # NormalizedString (alignments, transforms)
      pre_tokenizer.cr         # PreTokenizedString (split, tokenize, into_encoding)
      added_vocabulary.cr      # AddedVocabulary (special tokens, matching, normalization)
      pattern.cr               # SysRegex (PCRE2 wrapper), Invert, Pattern module
      input_sequence.cr        # InputSequence (raw vs pre-tokenized)

    normalizers/               # Normalizer implementations (10 types)
      mod.cr                   # NormalizerWrapper (tagged/untagged JSON dispatch)
      unicode.cr               # NFD, NFKD, NFC, NFKC, Nmt
      utils.cr                 # Lowercase, Sequence
      strip.cr                 # Strip, StripAccents
      replace.cr               # Replace (string/regex pattern)
      prepend.cr               # Prepend
      bert.cr                  # BertNormalizer
      byte_level.cr            # ByteLevel normalizer
      precompiled.cr           # Precompiled

    pre_tokenizers/            # Pre-tokenizer implementations (11 types)
      mod.cr                   # PreTokenizerWrapper (tagged JSON dispatch)
      whitespace.cr            # Whitespace, WhitespaceSplit
      byte_level.cr            # ByteLevel (GPT-2) + Decoder/PostProcessor + process_offsets
      metaspace.cr             # Metaspace (+ PrependScheme)
      digits.cr                # Digits
      punctuation.cr           # Punctuation
      split.cr                 # Split (pattern-based: char, string, regex)
      delimiter.cr             # CharDelimiterSplit
      fixed_length.cr          # FixedLength
      bert.cr                  # BertPreTokenizer
      sequence.cr              # Sequence (chain)
      unicode_scripts/         # UnicodeScripts pre-tokenizer (+ Script enum)

    processors/                # Post-processor implementations (4 types)
      mod.cr                   # PostProcessorWrapper (tagged/untagged JSON)
      bert.cr                  # BertProcessing ([CLS] ... [SEP])
      roberta.cr               # RobertaProcessing (<s> ... </s>) + offset trimming
      template.cr              # TemplateProcessing (Piece, SpecialToken, Template, TokensMap)
      sequence.cr              # SequenceProcessor (chain)

    decoders/                  # Decoder implementations (8 types)
      mod.cr                   # DecoderWrapper (tagged JSON dispatch)
      bpe.cr                   # BPEDecoder
      byte_fallback.cr         # ByteFallback
      ctc.cr                   # CTC
      fuse.cr                  # Fuse
      sequence.cr              # Sequence (chain)
      strip.cr                 # Strip
      wordpiece.cr             # WordPiece (+ cleanup helper)

    models/                    # Model implementations (4 families)
      mod.cr                   # ModelWrapper, TrainerWrapper (tagged union dispatch)
      bpe/                     # BPE model
        model.cr               # BPE model, BpeBuilder, vocab/merges, serialization
        trainer.cr             # BpeTrainer, BpeTrainerBuilder (inherits Trainer(BPE))
        builder.cr             # Builder pattern helpers
        cache.cr               # BpeCache
        types.cr               # Pair, MergeMap, Vocab, VocabR type aliases
        word.cr                # Word, Merge, Symbol
        iterators.cr           # MergeIter, WordIter
        error.cr               # Error types
      wordlevel/               # WordLevel model
        model.cr               # WordLevel model, WordLevelBuilder, serialization
        trainer.cr             # WordLevelTrainer
      wordpiece/               # WordPiece model
        model.cr               # WordPiece model (greedy longest-match), serialization
        trainer.cr             # WordPieceTrainer (wraps BpeTrainer)
      unigram/                 # Unigram model
        model.cr               # Unigram model, iterator, serialization
        trainer.cr             # UnigramTrainer (EM algorithm: digamma, e-step, m-step)
        lattice.cr             # Lattice (viterbi, nbest, populate_marginal, sample)
        trie.cr                # Trie, TrieBuilder

    utils/                     # Utility layer (ported)
      from_pretrained.cr       # HuggingFace Hub model download + caching
      parallelism.cr           # get_parallelism, set_parallelism (sequential)
      iter.cr                  # LinesWithEnding (line reading preserving \n/\r)
      progress.cr              # ProgressBar, ProgressStyle, ProgressFormat

spec/                          # Crystal specs — 299 examples, 0 failures
  spec_helper.cr               # Test configuration
  tokenizer/                   # Core tokenizer specs (encoding, truncation, padding, etc.)
  normalizers/                 # Normalizer specs
  pre_tokenizers/              # Pre-tokenizer specs
  processors/                  # Post-processor specs
  decoders/                    # Decoder specs
  models/                      # Model specs (BPE, WordLevel, WordPiece, Unigram)
  utils/                       # Utility specs (parallelism)
  integration/                 # Integration tests using external model data files
    documentation_spec.cr      # 6 tests: load_tokenizer, streaming, training, quicktour, pipeline, pipeline_bert
    training_spec.cr           # 2 tests: bpe_values_after_training, bpe_continuing_subword_prefix_error
    from_pretrained_spec.cr    # 4 tests: from_pretrained (2 network-gated)
    wiki_training_spec.cr      # 2 tests: quicktour_slow_train, train_pipeline_bert
    serialization_extra_spec.cr # 12 cross-model serialization round-trips
    added_tokens_spec.cr       # 5 tests
    offsets_spec.cr            # 5 tests
    offsets_bert_spec.cr       # 1 test
    stream_spec.cr             # 2 tests (partial Korean)
    unigram_spec.cr            # 3 tests (sample, from_file, train_from_file)

plans/
  porting_plan.md              # Feature checklist and completion status
  inventory/                   # Parity tracking manifests (TSV)
    rust_port_inventory.tsv    # Source API inventory (757 items)
    rust_source_parity.tsv     # Source API match status (515 items)
    rust_test_parity.tsv       # Test coverage status (242 tests, 0 missing)

scripts/                       # Parity check scripts (synced from cross-language-crystal-parity)
  check_port_inventory.sh      # Validate inventory statuses vs discovered source
  check_source_parity.sh       # Validate source API coverage
  check_test_parity.sh         # Validate test coverage
  verify_parity_adversarial.sh # Full adversarial verification
```

## Pipeline Architecture

The tokenizer pipeline processes raw text through five stages:

```
Input Text
    │
    ▼
┌──────────────┐
│  Normalizer   │  Unicode normalization, lowercasing, stripping
│               │  Outputs: NormalizedString (with alignment tracking)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ PreTokenizer  │  Split into word-level chunks (whitespace, byte-level, etc.)
│               │  Outputs: PreTokenizedString (splits with alignments)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│    Model      │  Tokenize chunks into sub-word IDs (BPE)
│               │  Outputs: Array(Token) per chunk
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ PostProcessor │  Add special tokens, set type IDs and sequence IDs
│               │  Outputs: final Encoding
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Decoder     │  Convert token IDs back to text (decode path only)
│               │  Input: Array(String) tokens
│               │  Output: String
└──────────────┘
```

The **Encoding** flows forward through the pipeline. The **Decoder** runs separately when `decode()` is called.

## Core Types

### Token (`src/tokens/token.cr`)

```crystal
record Token, id : UInt32, value : String, offsets : Tuple(UInt32, UInt32)
```

The fundamental unit produced by the Model. Contains the token ID, its string value, and byte offsets in the original text.

### Encoding (`src/tokens/tokenizer/encoding.cr`)

```crystal
struct Encoding
  getter ids : Array(UInt32)
  getter type_ids : Array(UInt32)
  getter tokens : Array(String)
  getter words : Array(UInt32?)
  getter offsets : Array(Tuple(UInt32, UInt32))
  getter special_tokens_mask : Array(UInt32)
  getter attention_mask : Array(UInt32)
  getter overflowing : Array(Encoding)
  getter sequence_ranges : Hash(UInt64, Range(UInt64, UInt64))
end
```

The output of the encoding pipeline. All arrays are aligned (index `i` in each array corresponds to the same token). `sequence_ranges` maps sequence IDs to token index ranges for multi-sequence (pair) encoding.

Key methods:
- `from_tokens(tokens, type_id)` — build from model output
- `merge(encodings, growing_offsets)` — merge multiple encodings (for pairs)
- `truncate(max_len, stride, direction)` — truncate with overflow
- `pad(target_length, pad_id, pad_type_id, pad_token, direction)` — add padding
- `token_to_sequence(token)`, `token_to_word(token)`, `char_to_token(pos, seq_id)` — alignment queries

### NormalizedString (`src/tokens/tokenizer/normalizer.cr`)

Tracks the normalized form of a string with alignment information that maps back to the original text. Supports transformations (replace, insert, delete) while maintaining character-level alignment.

### PreTokenizedString (`src/tokens/tokenizer/pre_tokenizer.cr`)

A collection of splits (substrings with alignment info). Each split can be independently tokenized by the model, and the results are merged into a single Encoding.

### TokenizerImpl (`src/tokens/tokenizer/tokenizer.cr`)

The main orchestrator. Holds references to all pipeline components and coordinates encode/decode flows:

```crystal
class TokenizerImpl
  getter model : Model
  getter normalizer : Normalizer?
  getter pre_tokenizer : PreTokenizer?
  getter post_processor : PostProcessor?
  getter decoder : Decoder?
  getter added_vocabulary : AddedVocabulary
  getter truncation : TruncationParams?
  getter padding : PaddingParams?
end
```

`Tokenizer` is a public wrapper that delegates all methods to `TokenizerImpl`.

## Abstract Modules

Each pipeline stage is defined as an abstract module in `src/tokens/tokenizer/tokenizer.cr`:

```crystal
module Normalizer
  abstract def normalize(normalized : NormalizedString) : Nil
end

module PreTokenizer
  abstract def pre_tokenize(pretokenized : PreTokenizedString) : Nil
end

module PostProcessor
  abstract def added_tokens(is_pair : Bool) : Int32
  abstract def process(encoding : Encoding, pair_encoding : Encoding?, add_special_tokens : Bool) : Encoding
end

module Decoder
  abstract def decode_chain(tokens : Array(String)) : Array(String)
  def decode(tokens : Array(String)) : String
    decode_chain(tokens).join
  end
end

module Model
  abstract def tokenize(sequence : String) : Array(Token)
  abstract def token_to_id(token : String) : UInt32?
  abstract def id_to_token(id : UInt32) : String?
  abstract def vocab : Hash(String, UInt32)
  abstract def vocab_size : UInt32
  abstract def save(folder : String, name : String? = nil) : Array(String)
  abstract def trainer
end
```

## Wrapper Pattern

Each component family uses a **Wrapper class** that acts as a tagged union for serialization:

| Component | Wrapper class | JSON tag |
|-----------|--------------|----------|
| Normalizer | `NormalizerWrapper` | `"type"` field (tagged) |
| PreTokenizer | `PreTokenizerWrapper` | `"type"` field (tagged) |
| PostProcessor | `PostProcessorWrapper` | `"type"` field (tagged), with fallback untagged matching for Bert/Roberta |
| Decoder | `DecoderWrapper` | `"type"` field (tagged) |

Each wrapper:
1. Defines a `Wrapped` type alias (union of all concrete types)
2. Includes the abstract module
3. Delegates all module methods to `@wrapped`
4. Implements `to_json` / `from_json` for tagged JSON serialization

Example pattern (from `normalizers/mod.cr`):
```crystal
class NormalizerWrapper
  alias Wrapped = NFC | NFD | NFKC | NFKD | Sequence | ... | ByteLevel
  include Tokens::Normalizer
  getter normalizer : Wrapped

  def normalize(normalized : NormalizedString) : Nil
    @normalizer.normalize(normalized)
  end

  def self.from_json(json : String) : self
    # Tag-based deserialization with fallback heuristics
  end
end
```

## Serialization

All components serialize to JSON matching the upstream `huggingface/tokenizers` format. Each concrete type implements:

- `to_json(json : JSON::Builder)` — writes JSON to a builder
- `self.from_json(json : String)` — parses JSON string

The wrapper classes handle discriminated deserialization using the `"type"` field. For post-processors, an **untagged** matching path exists for backward compatibility: Bert and Roberta can be deserialized from JSON without a `"type"` field by trying field-based matching (Roberta first, then Bert).

## Encoding Flow

The encode path in `TokenizerImpl`:

1. **Input processing** — string or tuple is wrapped in `InputSequence`
2. **Normalization** — `Normalizer` transforms the text, tracking alignments
3. **Added vocabulary matching** — special tokens extracted and normalized
4. **Pre-tokenization** — `PreTokenizer` splits into word chunks
5. **Tokenization** — `Model` tokenizes each chunk into `Array(Token)`
6. **Truncation** — if configured, encodings are truncated to max length
7. **Post-processing** — `PostProcessor` adds special tokens, sets type/sequence IDs, merges pairs
8. **Padding** — if configured, encoding is padded to target length

The decode path reverses this:
1. Token IDs are mapped to strings via `id_to_token`
2. `Decoder.decode_chain(tokens)` applies decoder transformations
3. Tokens are joined into the final string

## Truncation and Padding

Both are configured on the `TokenizerImpl` and applied during `post_process`:

```crystal
# Truncation
tokenizer.with_truncation(TruncationParams.new(
  max_length: 512_u64,
  strategy: TruncationStrategy::LongestFirst,
  direction: TruncationDirection::Right
))

# Padding
tokenizer.with_padding(PaddingParams.new(
  strategy: PaddingStrategy::Fixed,
  pad_id: 0_u32,
  pad_token: "[PAD]",
  fixed_size: 512_u64
))
```

## Parity Tracking

The `plans/inventory/` directory contains TSV manifests that track porting progress against the upstream Rust source:

- `rust_port_inventory.tsv` — every public API item (struct, enum, method, function, test) with status (`missing`, `in_progress`, `partial`, `ported`, `skipped`)
- `rust_source_parity.tsv` — source-level API match
- `rust_test_parity.tsv` — test coverage match

`plans/porting_plan.md` defines feature completion gates and tracks the current active feature.

## Upstream

The upstream Rust crate is at `vendor/tokenizers/tokenizers/`. It is organized as:

```
tokenizers/src/
  lib.rs
  tokenizer/    # Core tokenizer, encoding, normalizer, pre-tokenizer
  models/       # BPE, WordPiece, WordLevel, Unigram
  normalizers/  # Unicode, strip, replace, BERT, byte-level
  pre_tokenizers/  # Whitespace, byte-level, metaspace, punctuation, etc.
  processors/   # BERT, RoBERTa, template, sequence
  decoders/     # BPE, byte-level, CTC, WordPiece, etc.
  utils/        # Parallelism, progress, pretrained loading
```

All porting decisions preserve upstream semantics, parameter ordering, and error behavior.
