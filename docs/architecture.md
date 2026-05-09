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
      tokenizer.cr             # TokenizerImpl, DecodeStream, abstract modules
      normalizer.cr            # NormalizedString (alignments, transforms)
      pre_tokenizer.cr         # PreTokenizedString (split, tokenize)
      added_vocabulary.cr      # AddedVocabulary (special tokens, matching)
      pattern.cr               # SysRegex (PCRE2 wrapper)
      input_sequence.cr        # InputSequence (raw vs pre-tokenized)

    normalizers/               # Normalizer implementations
      mod.cr                   # NormalizerWrapper (tagged JSON, enum-like)
      unicode.cr               # NFC, NFD, NFKC, NFKD
      utils.cr                 # Lowercase, Sequence
      strip.cr                 # Strip, StripAccents
      replace.cr               # Replace (string/regex pattern)
      prepend.cr               # Prepend
      bert.cr                  # BertNormalizer
      byte_level.cr            # ByteLevel normalizer
      precompiled.cr           # Precompiled

    pre_tokenizers/            # Pre-tokenizer implementations
      mod.cr                   # PreTokenizerWrapper (tagged JSON, enum-like)
      whitespace.cr            # Whitespace, WhitespaceSplit
      byte_level.cr            # ByteLevel (GPT-2) + process_offsets helper
      metaspace.cr             # Metaspace
      digits.cr                # Digits
      punctuation.cr           # Punctuation
      split.cr                 # Split (pattern-based)
      delimiter.cr             # CharDelimiterSplit
      fixed_length.cr          # FixedLength
      bert.cr                  # BertPreTokenizer
      sequence.cr              # Sequence (chain)
      unicode_scripts/         # UnicodeScripts pre-tokenizer

    processors/                # Post-processor implementations
      mod.cr                   # PostProcessorWrapper (tagged/untagged JSON)
      bert.cr                  # BertProcessing ([CLS] ... [SEP])
      roberta.cr               # RobertaProcessing (<s> ... </s>)
      template.cr              # TemplateProcessing (Piece, SpecialToken, Template)
      sequence.cr              # SequenceProcessor (chain)

    decoders/                  # Decoder implementations
      mod.cr                   # DecoderWrapper (tagged JSON, enum-like)
      bpe.cr                   # BPEDecoder
      byte_fallback.cr         # ByteFallback
      ctc.cr                   # CTC
      fuse.cr                  # Fuse
      sequence.cr              # Sequence (chain)
      strip.cr                 # Strip
      wordpiece.cr             # WordPiece

    models/                    # Model implementations
      bpe/                     # BPE model
        model.cr               # BPE model, vocab, merges
        trainer.cr             # BpeTrainer
        builder.cr             # Builder pattern
        cache.cr               # Cache
        types.cr               # Pair, Merge types
        word.cr                # Word representation
        iterators.cr           # MergeIter, WordIter
        error.cr               # Error types

spec/                          # Crystal specs (ported from upstream Rust tests)
  tokenizer/                   # Core tokenizer specs
  normalizers/                 # Normalizer specs
  pre_tokenizers/              # Pre-tokenizer specs
  processors/                  # Post-processor specs
  decoders/                    # Decoder specs
  models/                      # Model specs (bpe_spec.cr)

plans/
  porting_plan.md              # Feature checklist and completion status
  inventory/                   # Parity tracking manifests (TSV)
    rust_port_inventory.tsv    # Source API inventory
    rust_source_parity.tsv     # Source API match status
    rust_test_parity.tsv       # Test coverage status
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
