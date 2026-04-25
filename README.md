# tokens

This repository is a Crystal port of https://github.com/huggingface/tokenizers.

Pinned upstream ref: [3992692](https://github.com/huggingface/tokenizers/tree/3992692d) (`main`, 2025-04-24)

Provides an implementation of today's most used tokenizers in pure Crystal, ported from the Rust upstream.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     tokens:
       github: dsisnero/tokens
   ```

2. Run `shards install`

## Usage

```crystal
require "tokens"
```

## Development

```bash
make install    # Install dependencies
make format     # Format Crystal code
make lint       # Run Ameba linter
make test       # Run specs
```

## Upstream README Highlights

huggingface/tokenizers provides implementations of today's most used tokenizers (Byte-Pair Encoding, WordPiece, Unigram) with a focus on performance and versatility. Key features:

- Train new vocabularies and tokenize using standard tokenizer models
- Normalization with alignment tracking (map tokens back to original text)
- Pre-processing: Truncate, Pad, add special tokens
- Rust core with Python, Node.js, and Ruby bindings

This Crystal port follows the Rust implementation at `vendor/tokenizers/tokenizers/`.

## Contributing

1. Fork it (<https://github.com/dsisnero/tokens/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer
