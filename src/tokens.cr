require "./tokens/extensions"
require "./tokens/model"
require "./tokens/token"
require "./tokens/tokenizer"
require "./tokens/models"
require "./tokens/pre_tokenizers"
require "./tokens/normalizers"
require "./tokens/decoders"
require "./tokens/processors"
require "./tokens/utils/from_pretrained"
require "./tokens/utils/parallelism"
require "./tokens/utils/iter"
require "./tokens/utils/progress"

module Tokens
  VERSION = {{ read_file("#{__DIR__}/../shard.yml").lines.select(&.starts_with?("version:")).first.split(":").last.strip }}
end
