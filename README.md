# tokens

A Crystal port of [huggingface/tokenizers](https://github.com/huggingface/tokenizers).

**Pinned upstream ref:** [3992692](https://github.com/huggingface/tokenizers/tree/3992692d) (`main`, 2025-04-24)

Provides implementations of today's most used tokenizers in pure Crystal, ported from the upstream Rust crate at `vendor/tokenizers/tokenizers/`.

## What is a Tokenizer

A tokenizer works as a pipeline — raw text goes in, an `Encoding` comes out. The pipeline has five stages:

| Stage | Role | Crystal module |
|-------|------|---------------|
| **Normalizer** | Unicode normalization, lowercasing, stripping | `Tokens::Normalizer` |
| **PreTokenizer** | Split text into initial word-level chunks | `Tokens::PreTokenizer` |
| **Model** | Tokenize chunks into sub-word IDs | `Tokens::Model` (BPE) |
| **PostProcessor** | Add special tokens ([CLS], [SEP]) | `Tokens::PostProcessor` |
| **Decoder** | Convert token IDs back to text | `Tokens::Decoder` |

## Features

- **BPE model** — train, save/load, encode, decode
- **Normalizers** — NFC, NFD, NFKC, NFKD, Lowercase, Strip, StripAccents, Replace, Prepend, BertNormalizer, ByteLevel, Sequence
- **Pre-tokenizers** — Whitespace, ByteLevel, Metaspace, Digits, Punctuation, Split, Delimiter, FixedLength, BertPreTokenizer, UnicodeScripts, Sequence
- **Post-processors** — BertProcessing, RobertaProcessing, TemplateProcessing, ByteLevel, Sequence
- **Decoders** — BPE, ByteLevel, ByteFallback, CTC, Fuse, Strip, WordPiece, Metaspace, Sequence
- **Serialization** — JSON round-trip for all pipeline components (compatible with upstream format)
- **Alignment tracking** — map tokens back to original character offsets
- **Truncation & padding** — with direction and strategy control

## Installation

Add to your `shard.yml`:

```yaml
dependencies:
  tokens:
    github: dsisnero/tokens
```

Then:

```bash
shards install
```

## Quick example

```crystal
require "tokens"

# Build a tokenizer from JSON (compatible with upstream format)
tokenizer = Tokens::TokenizerImpl.new(Tokens::Models::BPE.default)
  .with_normalizer(Tokens::NormalizerWrapper.from(Tokens::Normalizers::NFC.new))
  .with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::ByteLevel.default))
  .with_post_processor(Tokens::PostProcessorWrapper.from(Tokens::PostProcessors::BertProcessing.default))
  .with_decoder(Tokens::DecoderWrapper.from(Tokens::Decoders::BPEDecoder.default))

# Encode text
encoding = tokenizer.encode("Hello there!", add_special_tokens: true)
encoding.tokens # => ["[CLS]", "Hello", "there", "!", "[SEP]"]

# Decode back
tokenizer.decode(encoding.ids) # => "Hello there !"
```

## Usage

```crystal
require "tokens"

# Create a tokenizer with a BPE model
bpe = Tokens::Models::BPE.from_files("vocab.json", "merges.txt")
tokenizer = Tokens::Tokenizer.new(bpe)

# Encode
encoding = tokenizer.encode("Hello world!")
puts encoding.tokens   # => ["Hello", "Ġworld", "!"]
puts encoding.ids      # => [15496, 2159, 0]

# Encode a pair
encoding = tokenizer.encode({"Hello", "world"})
puts encoding.type_ids # => [0, 1]

# Decode
text = tokenizer.decode(encoding.ids)
puts text # => "Hello world"
```

### JSON serialization

All pipeline components serialize to/from the upstream JSON format:

```crystal
# Serialize a normalizer
normalizer = Tokens::NormalizerWrapper.from(Tokens::Normalizers::NFC.new)
normalizer.to_json # => {"type":"NFC"}

# Deserialize
copy = Tokens::NormalizerWrapper.from_json(%({"type":"NFC"}))
```

## Pipeline details

### Normalizers

```crystal
# Unicode normalization
tokenizer.with_normalizer(Tokens::Normalizers::NFC.new)

# Sequence of normalizers
seq = Tokens::Normalizers::Sequence.new([
  Tokens::NormalizerWrapper.from(Tokens::Normalizers::Strip.new(true, true)),
  Tokens::NormalizerWrapper.from(Tokens::Normalizers::NFC.new),
])
tokenizer.with_normalizer(seq)
```

### Pre-tokenizers

```crystal
# Byte-level pre-tokenization (GPT-2 style)
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::ByteLevel.default)

# Whitespace splitting
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)
```

### Post-processors

```crystal
# BERT-style [CLS] ... [SEP]
tokenizer.with_post_processor(Tokens::PostProcessors::BertProcessing.default)

# RoBERTa-style <s> ... </s> with offset trimming
tokenizer.with_post_processor(Tokens::PostProcessors::RobertaProcessing.default)

# Template-based (fully customizable)
template = Tokens::PostProcessors::TemplateProcessing.build(
  single: Tokens::PostProcessors::ProcTemplate.parse("[CLS] $0 [SEP]"),
  pair: Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0 $B:1 [SEP]:1"),
  special_tokens: Tokens::PostProcessors::TokensMap.from_tuples([
    {"[CLS]", 1_u32},
    {"[SEP]", 0_u32},
  ])
)
```

### Decoders

```crystal
# BPE decoder
tokenizer.with_decoder(Tokens::Decoders::BPEDecoder.default)

# Byte-level decoder
tokenizer.with_decoder(Tokens::PreTokenizers::ByteLevel.default)
```

## Documentation

- [Architecture](docs/architecture.md) — codebase structure and design
- [Development](docs/development.md) — setup and quality gates
- [Testing](docs/testing.md) — testing strategy
- [Coding Guidelines](docs/coding-guidelines.md) — porting conventions
- [PR Workflow](docs/pr-workflow.md) — pull request process

## Development

```bash
make install    # Install dependencies
make format     # Format Crystal code
make lint       # Run Ameba linter
make test       # Run specs
```

## Upstream

This is a behavior-faithful port of [huggingface/tokenizers](https://github.com/huggingface/tokenizers). The upstream Rust implementation is vendored at `vendor/tokenizers/` (pinned at `3992692`) and serves as the source of truth for all porting decisions.

## Contributing

1. Fork it (<https://github.com/dsisnero/tokens/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) — creator and maintainer
