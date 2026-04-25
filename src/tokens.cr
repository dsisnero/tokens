require "./tokens/extensions"
require "./tokens/model"
require "./tokens/models/bpe"

module Tokens
  VERSION = {{ read_file("#{__DIR__}/../shard.yml").lines.select(&.starts_with?("version:")).first.split(":").last.strip }}
end
