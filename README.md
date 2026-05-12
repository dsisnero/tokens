# tokens

A Crystal port of [huggingface/tokenizers](https://github.com/huggingface/tokenizers) — provides implementations of today's most used tokenizers in pure Crystal.

**Upstream pinned ref:** [`3992692`](https://github.com/huggingface/tokenizers/tree/3992692d) (`main`, 2025-04-24)

[![Crystal](https://img.shields.io/badge/Crystal-1.20+-776791.svg)](https://crystal-lang.org)
![Tests](https://img.shields.io/badge/specs-299-green)
![Parity](https://img.shields.io/badge/parity-0%20missing-green)

## Features

### Models (4 families)
| Model | Training | Serialization | Description |
|---|---|---|---|
| **BPE** | `BpeTrainer` | JSON, vocab+merges files | Byte-Pair Encoding (GPT-2, RoBERTa) |
| **WordPiece** | `WordPieceTrainer` | JSON, vocab file | Greedy longest-match (BERT) |
| **WordLevel** | `WordLevelTrainer` | JSON | Simple word-to-id mapping |
| **Unigram** | `UnigramTrainer` (EM) | JSON | Viterbi lattice + n-best sampling |

### Pipeline Components (33 types)
| Stage | Types | Wrapper |
|---|---|---|
| **Normalizer** (10) | NFC, NFD, NFKC, NFKD, Nmt, Lowercase, Strip, StripAccents, Replace, Prepend, BertNormalizer, ByteLevel, Precompiled, Sequence | `NormalizerWrapper` |
| **PreTokenizer** (11) | Whitespace, WhitespaceSplit, ByteLevel, Metaspace, Digits, Punctuation, Split, Delimiter, FixedLength, BertPreTokenizer, UnicodeScripts, Sequence | `PreTokenizerWrapper` |
| **PostProcessor** (4) | BertProcessing, RobertaProcessing, TemplateProcessing, SequenceProcessor | `PostProcessorWrapper` |
| **Decoder** (8) | BPEDecoder, ByteLevel, ByteFallback, CTC, Fuse, Strip, WordPiece, Metaspace, Sequence | `DecoderWrapper` |

### Utilities
- **from_pretrained** — download tokenizers from HuggingFace Hub
- **train_from_files** — train models from text files
- **encode_batch** — batch encoding with padding
- **LinesWithEnding** — line reading preserving `\n`/`\r`
- **ProgressBar** — training progress reporting
- **Parallelism** — parallelism configuration API

### Serialization
- JSON round-trip for all pipeline components (compatible with upstream format)
- Tagged/untagged JSON dispatch
- Cross-model tokenizer save/load

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

## Quick Example

```crystal
require "tokens"

# Build a BPE tokenizer from scratch
model = Tokens::Models::BPE::BpeBuilder.new
  .unk_token("[UNK]")
  .build

tokenizer = Tokens::TokenizerImpl.new(model)
  .with_normalizer(Tokens::Normalizers::NFC.new)
  .with_pre_tokenizer(Tokens::PreTokenizers::ByteLevel.default)
  .with_post_processor(Tokens::PostProcessors::BertProcessing.default)
  .with_decoder(Tokens::Decoders::BPEDecoder.default)

# Train from files
trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
  .show_progress(false)
  .vocab_size(1000)
  .build
tokenizer.train_from_files(trainer, ["data/small.txt"])

# Encode
encoding = tokenizer.encode("Hello there!", add_special_tokens: true)
encoding.tokens # => ["[CLS]", "Hello", "there", "!", "[SEP]"]

# Decode
tokenizer.decode(encoding.ids) # => "Hello there !"

# Serialize
File.write("tokenizer.json", tokenizer.to_json)
loaded = Tokens::TokenizerImpl.from_json(File.read("tokenizer.json"))

# Download from HuggingFace Hub
tokenizer = Tokens::TokenizerImpl.from_pretrained("bert-base-cased")
```

## Pipeline Details

### Normalizers

```crystal
# Unicode normalization
tokenizer.with_normalizer(Tokens::Normalizers::NFC.new)

# BERT-style normalization (NFD + Lowercase + StripAccents)
seq = Tokens::Normalizers::Sequence.new([
  Tokens::Normalizers::NFD.new,
  Tokens::Normalizers::Lowercase.new,
  Tokens::Normalizers::StripAccents.new,
])
tokenizer.with_normalizer(seq)

# Byte-level normalizer (GPT-2 style)
tokenizer.with_normalizer(Tokens::Normalizers::ByteLevel.new)
```

### Pre-tokenizers

```crystal
# Byte-level pre-tokenization (GPT-2 style)
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::ByteLevel.default)

# Whitespace splitting
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)

# Combined: Whitespace + split individual digits
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Sequence.new([
  Tokens::PreTokenizers::Whitespace.new,
  Tokens::PreTokenizers::Digits.new(true),
]))
```

### Post-processors

```crystal
# BERT-style [CLS] ... [SEP]
tokenizer.with_post_processor(Tokens::PostProcessors::BertProcessing.default)

# RoBERTa-style <s> ... </s> with offset trimming
tokenizer.with_post_processor(Tokens::PostProcessors::RobertaProcessing.default)

# Template-based (fully customizable)
tokenizer.with_post_processor(
  Tokens::PostProcessors::TemplateProcessing.build(
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP]"),
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP] $B:1 [SEP]:1"),
    Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", 1_u32},
      {"[SEP]", 2_u32},
    ]),
  )
)
```

### Decoders

```crystal
# BPE decoder
tokenizer.with_decoder(Tokens::Decoders::BPEDecoder.default)

# Byte-level decoder (doubles as PostProcessor)
tokenizer.with_decoder(Tokens::PreTokenizers::ByteLevel.default)

# WordPiece decoder (strips ## prefixes)
tokenizer.with_decoder(Tokens::Decoders::WordPiece.default)
```

### Training

```crystal
# BPE training
trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
  .vocab_size(30000)
  .min_frequency(2_u64)
  .special_tokens([
    Tokens::AddedToken.new("[UNK]", true),
    Tokens::AddedToken.new("[CLS]", true),
    Tokens::AddedToken.new("[SEP]", true),
  ])
  .build
tokenizer.train_from_files(trainer, ["data/corpus.txt"])

# WordPiece training (delegates to BPE)
trainer = Tokens::Models::WordPieceTrainer.new(show_progress: false)
tokenizer.train_from_files(trainer, ["data/corpus.txt"])

# Unigram EM training
trainer = Tokens::Models::Unigram::UnigramTrainer.new(
  show_progress: false,
  unk_token: "<UNK>",
)
sentences = [{"word1", 5_u64}, {"word2", 3_u64}]
trainer.do_train(sentences, model)
```

### Truncation & Padding

```crystal
# Truncate sequences longer than 512 tokens
tokenizer.with_truncation(Tokens::TruncationParams.new(
  max_length: 512_u64,
  strategy: Tokens::TruncationStrategy::LongestFirst,
))

# Pad batches to match longest sequence
tokenizer.with_padding(Tokens::PaddingParams.new(
  pad_id: 0_u32,
  pad_token: "[PAD]",
))
```

## Documentation

- [Architecture](docs/architecture.md) — codebase structure, pipeline design, core types
- [Development](docs/development.md) — setup, quality gates, parity checks
- [Testing](docs/testing.md) — test categories, test data, running tests
- [Parity Tracking](docs/parity.md) — inventory manifests, status vocabulary, parity checks
- [Coding Guidelines](docs/coding-guidelines.md) — porting conventions
- [PR Workflow](docs/pr-workflow.md) — pull request process
- [Porting Plan](plans/porting_plan.md) — feature checklist and completion status

## Development

```bash
make install         # Install dependencies
make download-data   # Download test model files
make format          # Format Crystal code
make lint            # Run Ameba linter
make test            # Run specs (299 examples)
make test-all        # download-data + crystal spec
```

## Parity

| Metric | Status |
|---|---|
| Specs | 299 examples, 0 failures, 0 pending |
| Tests ported | 241/242 (1 partial — Unigram esaxx) |
| Source API tracked | 757 items, 0 missing |
| Adversarial verification | PASSED |

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
