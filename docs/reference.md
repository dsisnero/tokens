# Reference

A reference of all pipeline components, models, and utilities with code examples.

## Models

| Model | Tokenization | Training | Use Case |
|---|---|---|---|
| **BPE** | Byte-Pair Encoding with merge table | `BpeTrainer` (frequency-based pair merging) | GPT-2, RoBERTa, LLaMA |
| **WordPiece** | Greedy longest-match with `##` prefix | `WordPieceTrainer` (delegates to BPE) | BERT, DistilBERT |
| **WordLevel** | Simple word-to-id mapping | `WordLevelTrainer` | Simple classification models |
| **Unigram** | Viterbi lattice + n-best sampling | `UnigramTrainer` (EM algorithm) | XLNet, ALBERT |

### BPE

```crystal
# Build from files
bpe = Tokens::Models::BPE.from_files("vocab.json", "merges.txt").build

# Build from scratch
bpe = Tokens::Models::BPE::BpeBuilder.new
  .unk_token("[UNK]")
  .dropout(0.1_f32)
  .continuing_subword_prefix("Ġ")
  .build

# Train
trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
  .vocab_size(30000)
  .min_frequency(2_u64)
  .special_tokens([Tokens::AddedToken.new("[UNK]", true)])
  .build
trainer.do_train(word_counts, bpe)

# Save
files = bpe.save("output/") # => ["output/vocab.json", "output/merges.txt"]
```

### WordPiece

```crystal
# Build from vocab file
wp = Tokens::Models::WordPiece.build(
  vocab: Tokens::Models::WordPiece.read_file("data/bert-base-uncased-vocab.txt"),
  unk_token: "[UNK]",
)

# From a BPE model
wp = Tokens::Models::WordPiece.from_bpe(bpe_model)
```

### Unigram

```crystal
# Default model
model = Tokens::Models::Unigram::Unigram.default

# Train with EM
trainer = Tokens::Models::Unigram::UnigramTrainer.new(
  show_progress: false,
  unk_token: "<UNK>",
)
sentences = [{"word1", 5_u64}, {"word2", 3_u64}]
trainer.do_train(sentences, model)

# Viterbi decoding
lattice = Tokens::Models::Unigram::Lattice.new("hello world", 0, 2)
tokens = lattice.viterbi
```

### WordLevel

```crystal
# Build from file
wl = Tokens::Models::WordLevel.from_file("vocab.json")

# Build from hash
wl = Tokens::Models::WordLevel.build({"hello" => 0_u32, "world" => 1_u32})
```

## Normalizers (10 types)

| Type | Description | Example |
|---|---|---|
| `NFC` | Unicode NFC normalization | `Tokens::Normalizers::NFC.new` |
| `NFD` | Unicode NFD decomposition | `Tokens::Normalizers::NFD.new` |
| `NFKC` | Unicode NFKC (compatibility) | `Tokens::Normalizers::NFKC.new` |
| `NFKD` | Unicode NFKD (compatibility decomposition) | `Tokens::Normalizers::NFKD.new` |
| `Nmt` | Nmt normalization | `Tokens::Normalizers::Nmt.new` |
| `Lowercase` | Convert to lowercase | `Tokens::Normalizers::Lowercase.new` |
| `Strip` | Strip leading/trailing whitespace | `Tokens::Normalizers::Strip.new(true, true)` |
| `StripAccents` | Remove combining diacritical marks | `Tokens::Normalizers::StripAccents.new` |
| `Replace` | Replace pattern with string | `Tokens::Normalizers::Replace.new(pattern, replacement)` |
| `Prepend` | Prepend string | `Tokens::Normalizers::Prepend.new("▁")` |
| `BertNormalizer` | BERT-specific normalization | `Tokens::Normalizers::BertNormalizer.new` |
| `ByteLevel` | Byte-level encoding normalization | `Tokens::Normalizers::ByteLevel.new` |
| `Precompiled` | Pre-compiled replace map | `Tokens::Normalizers::Precompiled.new(map)` |
| `Sequence` | Chain multiple normalizers | `Tokens::Normalizers::Sequence.new([...])` |

```crystal
# Chain normalizers
normalizer = Tokens::Normalizers::Sequence.new([
  Tokens::Normalizers::Strip.new(true, true),
  Tokens::Normalizers::NFD.new,
  Tokens::Normalizers::StripAccents.new,
  Tokens::Normalizers::Lowercase.new,
])

# Apply directly
normalized = Tokens::NormalizedString.new("  Héllo Wörld!  ")
normalizer.normalize(normalized)
normalized.get # => "hello world!"
```

## Pre-Tokenizers (11 types)

| Type | Description | Example |
|---|---|---|
| `Whitespace` | Split on `\w+` and `[^\w\s]+` | `Tokens::PreTokenizers::Whitespace.new` |
| `WhitespaceSplit` | Split on whitespace characters only | `Tokens::PreTokenizers::WhitespaceSplit.new` |
| `ByteLevel` | GPT-2 style byte-level pre-tokenization (also implements Decoder + PostProcessor) | `Tokens::PreTokenizers::ByteLevel.default` |
| `Metaspace` | Replace space with meta character (`▁`) | `Tokens::PreTokenizers::Metaspace.new("▁")` |
| `Digits` | Split individual digits | `Tokens::PreTokenizers::Digits.new(true)` |
| `Punctuation` | Isolate punctuation characters | `Tokens::PreTokenizers::Punctuation.new` |
| `Split` | Split on custom pattern | `Tokens::PreTokenizers::Split.new(pattern, behavior)` |
| `CharDelimiterSplit` | Split on character delimiter | `Tokens::PreTokenizers::CharDelimiterSplit.new('-')` |
| `FixedLength` | Split into fixed-length chunks | `Tokens::PreTokenizers::FixedLength.new(4)` |
| `BertPreTokenizer` | BERT pre-tokenization (Chinese chars + whitespace) | `Tokens::PreTokenizers::BertPreTokenizer.new` |
| `UnicodeScripts` | Split on Unicode script boundaries | `Tokens::PreTokenizers::UnicodeScripts.new` |
| `Sequence` | Chain multiple pre-tokenizers | `Tokens::PreTokenizers::Sequence.new([...])` |

```crystal
# GPT-2 style ByteLevel (replaces spaces with Ġ)
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::ByteLevel.default)

# Combined: whitespace then split digits
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Sequence.new([
  Tokens::PreTokenizers::Whitespace.new,
  Tokens::PreTokenizers::Digits.new(true),
]))
```

## Post-Processors (4 types)

| Type | Description | Example |
|---|---|---|
| `BertProcessing` | Add `[CLS]` and `[SEP]` tokens | `Tokens::PostProcessors::BertProcessing.default` |
| `RobertaProcessing` | Add `<s>` and `</s>` with offset trimming | `Tokens::PostProcessors::RobertaProcessing.default` |
| `TemplateProcessing` | Fully customizable template | `ProcTemplate.parse("[CLS] $A [SEP]")` |
| `SequenceProcessor` | Chain multiple post-processors | `Tokens::PostProcessors::SequenceProcessor.new([...])` |

```crystal
# BERT-style [CLS] ... [SEP]
tokenizer.with_post_processor(Tokens::PostProcessors::BertProcessing.default)

# Custom template
tokenizer.with_post_processor(
  Tokens::PostProcessors::TemplateProcessing.build(
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP]"),
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP] $B:1 [SEP]:1"),
    Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", 1_u32}, {"[SEP]", 2_u32},
    ]),
  )
)
```

## Decoders (8 types)

| Type | Description | Example |
|---|---|---|
| `BPEDecoder` | BPE merge decoder (replaces `</w>` suffix) | `Tokens::Decoders::BPEDecoder.default` |
| `ByteLevel` | Byte-level decode (in `PreTokenizers::ByteLevel`) | `Tokens::PreTokenizers::ByteLevel.default` |
| `ByteFallback` | Byte-level fallback for unknown tokens | `Tokens::Decoders::ByteFallback.new` |
| `CTC` | CTC decode (removes duplicates + blank) | `Tokens::Decoders::CTC.new` |
| `Fuse` | Fuse adjacent tokens | `Tokens::Decoders::Fuse.new` |
| `Strip` | Strip content from each token | `Tokens::Decoders::Strip.new("left", "right")` |
| `WordPiece` | Strip `##` prefix and clean up spaces | `Tokens::Decoders::WordPiece.default` |
| `Metaspace` | Reverse Metaspace pre-tokenization | `Tokens::Decoders::Metaspace.new` |
| `Sequence` | Chain multiple decoders | `Tokens::Decoders::Sequence.new([...])` |

```crystal
# WordPiece decoder for BERT
tokenizer.with_decoder(Tokens::Decoders::WordPiece.default)

# Byte-level decoder
tokenizer.with_decoder(Tokens::PreTokenizers::ByteLevel.default)
```

## Truncation & Padding

```crystal
# Truncation
tokenizer.with_truncation(Tokens::TruncationParams.new(
  max_length: 512_u64,
  strategy: Tokens::TruncationStrategy::LongestFirst,
  stride: 0_u64,
  direction: Tokens::TruncationDirection::Right,
))

# Padding
tokenizer.with_padding(Tokens::PaddingParams.new(
  strategy: Tokens::PaddingStrategy::Fixed,
  pad_id: 0_u32,
  pad_token: "[PAD]",
  fixed_size: 512_u64,
))
```

## Utilities

### from_pretrained

Download tokenizers from HuggingFace Hub:

```crystal
tokenizer = Tokens::TokenizerImpl.from_pretrained("bert-base-cased")
tokenizer = Tokens::TokenizerImpl.from_pretrained(
  "anthony/tokenizers-test",
  Tokens::FromPretrainedParameters.new(revision: "gpt-2"),
)
```

Models are cached in `data/from_pretrained/<identifier>/tokenizer.json`.

### Encoding

```crystal
encoding = tokenizer.encode("Hello world!", add_special_tokens: true)

# Access fields
encoding.ids               # => [1, 7592, 2088, 0, 2]
encoding.tokens            # => ["[CLS]", "Hello", "world", "!", "[SEP]"]
encoding.offsets           # => [(0, 0), (0, 5), (6, 11), (11, 12), (0, 0)]
encoding.type_ids          # => [0, 0, 0, 0, 0]
encoding.attention_mask    # => [1, 1, 1, 1, 1]
encoding.special_tokens_mask # => [1, 0, 0, 0, 1]

# Alignment queries
encoding.token_to_word(1)       # => 0_u32?
encoding.char_to_token(0, 0)    # => 1_u32?
```

### Pair Encoding

```crystal
encoding = tokenizer.encode({"Hello", "world!"}, add_special_tokens: true)
encoding.tokens   # => ["[CLS]", "Hello", "[SEP]", "world", "!", "[SEP]"]
encoding.type_ids # => [0, 0, 0, 1, 1, 1]
```
