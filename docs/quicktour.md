# Quicktour

A quick tour of the `tokens` Crystal library — a port of 🤗 Tokenizers.

## Build a Tokenizer from Scratch

Let's build and train a Byte-Pair Encoding (BPE) tokenizer. BPE starts with individual characters as tokens and repeatedly merges the most common pairs until reaching the target vocabulary size.

### Create a BPE Model

```crystal
require "tokens"

model = Tokens::Models::BPE::BpeBuilder.new
  .unk_token("[UNK]")
  .build
```

### Configure the Trainer

The `BpeTrainer` controls training parameters like vocabulary size, minimum frequency, and special tokens:

```crystal
trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
  .vocab_size(30000)
  .min_frequency(2_u64)
  .special_tokens([
    Tokens::AddedToken.new("[UNK]", true),
    Tokens::AddedToken.new("[CLS]", true),
    Tokens::AddedToken.new("[SEP]", true),
    Tokens::AddedToken.new("[PAD]", true),
    Tokens::AddedToken.new("[MASK]", true),
  ])
  .build
```

### Configure Pre-Tokenization

Pre-tokenizers split raw text into word-level chunks before the model tokenizes them:

```crystal
tokenizer = Tokens::TokenizerImpl.new(model)
tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)
```

### Train the Tokenizer

```crystal
files = ["data/wikitext-103-raw/wiki.train.raw"]
tokenizer.train_from_files(trainer, files)
```

### Save and Reload

```crystal
# Save
File.write("data/tokenizer-wiki.json", tokenizer.to_json)

# Reload
tokenizer = Tokens::TokenizerImpl.from_json(File.read("data/tokenizer-wiki.json"))
```

## Encoding Text

```crystal
output = tokenizer.encode("Hello, y'all! How are you 😁 ?", add_special_tokens: true)

puts output.tokens
# => ["Hello", ",", "y", "'", "all", "!", "How", "are", "you", "[UNK]", "?"]

puts output.ids
# => [27253, 16, 93, 11, 5097, 5, 7961, 5112, 6218, 0, 35]
```

## Adding Post-Processing

Post-processors add special tokens like `[CLS]` and `[SEP]` for language models:

```crystal
tokenizer.with_post_processor(
  Tokens::PostProcessors::TemplateProcessing.build(
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP]"),
    Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP] $B:1 [SEP]:1"),
    Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", tokenizer.token_to_id("[CLS]").not_nil!},
      {"[SEP]", tokenizer.token_to_id("[SEP]").not_nil!},
    ]),
  )
)

output = tokenizer.encode("Hello, y'all! How are you 😁 ?", add_special_tokens: true)
puts output.tokens
# => ["[CLS]", "Hello", ",", "y", "'", "all", "!", "How", "are", "you", "[UNK]", "?", "[SEP]"]

# Pair encoding
output = tokenizer.encode({"Hello, y'all!", "How are you 😁 ?"}, add_special_tokens: true)
puts output.type_ids
# => [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]
```

## Batch Encoding and Padding

```crystal
# Enable padding
tokenizer.with_padding(Tokens::PaddingParams.new(
  pad_id: 3_u32,
  pad_token: "[PAD]",
))

# Encode multiple sentences at once
output = tokenizer.encode_batch(["Hello, y'all!", "How are you 😁 ?"], add_special_tokens: true)

# Shorter sequence gets padded
puts output[1].tokens
# => ["[CLS]", "How", "are", "you", "[UNK]", "?", "[SEP]", "[PAD]"]

puts output[1].attention_mask
# => [1, 1, 1, 1, 1, 1, 1, 0]
```

## Decoding

```crystal
tokenizer.decode([27253_u32, 16_u32, 93_u32, 11_u32, 5097_u32, 5_u32, 7961_u32, 5112_u32, 6218_u32, 0_u32, 35_u32])
# => "Hello , y ' all ! How are you ?"
```

## Working with Pre-Trained Tokenizers

### Load from File

```crystal
tokenizer = Tokens::TokenizerImpl.from_json(File.read("data/roberta.json"))

encoding = tokenizer.encode("This is an example", add_special_tokens: false)
encoding.tokens # => ["This", "Ġis", "Ġan", "Ġexample"]
encoding.ids    # => [713, 16, 41, 1246]

tokenizer.decode(encoding.ids, skip_special_tokens: false)
# => "This is an example"
```

### Download from HuggingFace Hub

```crystal
# Requires network access
tokenizer = Tokens::TokenizerImpl.from_pretrained("bert-base-cased")
encoding = tokenizer.encode("Hey there dear friend!", add_special_tokens: false)
encoding.tokens # => ["Hey", "there", "dear", "friend", "!"]
```

## Pipeline Components

The tokenizer pipeline processes text through five configurable stages:

```
Input Text
  → Normalizer (unicode, lowercasing, stripping)
  → PreTokenizer (split into words)
  → Model (tokenize into sub-word IDs)
  → PostProcessor (add special tokens)
  → Decoder (convert IDs back to text)
```

### Normalizer Example

```crystal
# BERT-style normalization: NFD + Lowercase + StripAccents
normalizer = Tokens::Normalizers::Sequence.new([
  Tokens::Normalizers::NFD.new,
  Tokens::Normalizers::Lowercase.new,
  Tokens::Normalizers::StripAccents.new,
])

normalized = Tokens::NormalizedString.new("Héllò hôw are ü?")
normalizer.normalize(normalized)
normalized.get # => "Hello how are u?"
```

### PreTokenizer Example

```crystal
# Whitespace splitting
pre_tokenizer = Tokens::PreTokenizers::Whitespace.new
pretokenized = Tokens::PreTokenizedString.new("Hello! How are you? I'm fine, thank you.")
pre_tokenizer.pre_tokenize(pretokenized)

splits = pretokenized.get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
# => [("Hello", (0, 5)), ("!", (5, 6)), ("How", (7, 10)), ...]
```

### WordPiece (BERT) Tokenizer

```crystal
# BERT uses WordPiece with greedy longest-match tokenization
tokenizer = Tokens::TokenizerImpl.from_json(File.read("data/bert-wiki.json"))

output = tokenizer.encode("Welcome to the 🤗 Tokenizers library.", add_special_tokens: true)
output.tokens
# => ["[CLS]", "welcome", "to", "the", "[UNK]", "tok", "##eni", "##zer", "##s", "library", ".", "[SEP]"]

# Add WordPiece decoder (strips ## prefixes)
tokenizer.with_decoder(Tokens::Decoders::WordPiece.default)
tokenizer.decode(output.ids, skip_special_tokens: true)
# => "welcome to the tokenizers library."
```

## Streaming Decode

For real-time applications, decode token-by-token:

```crystal
stream = tokenizer.decode_stream(skip_special_tokens: false)
stream.step(713_u32)  # => "This"
stream.step(16_u32)   # => " is"
stream.step(41_u32)   # => " an"
stream.step(1246_u32) # => " example"
```

## Truncation and Padding

```crystal
# Truncate sequences longer than 512
tokenizer.with_truncation(Tokens::TruncationParams.new(
  max_length: 512_u64,
  strategy: Tokens::TruncationStrategy::LongestFirst,
  direction: Tokens::TruncationDirection::Right,
))

# Pad to fixed length
tokenizer.with_padding(Tokens::PaddingParams.new(
  pad_id: 0_u32,
  pad_token: "[PAD]",
  fixed_size: 128_u64,
))
```
