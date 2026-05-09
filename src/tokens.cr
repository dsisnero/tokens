require "./tokens/extensions"
require "./tokens/model"
require "./tokens/token"
require "./tokens/models/bpe"
require "./tokens/tokenizer"
require "./tokens/pre_tokenizers"
require "./tokens/normalizers"
require "./tokens/decoders"
require "./tokens/processors"

module Tokens
  VERSION = {{ read_file("#{__DIR__}/../shard.yml").lines.select(&.starts_with?("version:")).first.split(":").last.strip }}
end
