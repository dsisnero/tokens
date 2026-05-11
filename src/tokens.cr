require "./tokens/extensions"
require "./tokens/model"
require "./tokens/token"
require "./tokens/tokenizer"
require "./tokens/models/bpe"
require "./tokens/models/wordlevel"
require "./tokens/pre_tokenizers"
require "./tokens/normalizers"
require "./tokens/decoders"
require "./tokens/processors"

module Tokens
  VERSION = {{ read_file("#{__DIR__}/../shard.yml").lines.select(&.starts_with?("version:")).first.split(":").last.strip }}
end
