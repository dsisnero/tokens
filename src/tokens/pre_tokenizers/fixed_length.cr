require "json"

module Tokens
  module PreTokenizers
    struct FixedLength
      include Tokens::PreTokenizer

      getter length : Int32

      def initialize(length = 5)
        @length = length.to_i32
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          text = normalized.get
          next [] of Tokens::Split if text.empty?

          Tokens::NormalizedString.byte_char_entries(text)
            .in_groups_of(@length, filled_up_with: nil)
            .compact_map do |chunk|
              entries = chunk.compact
              next nil if entries.empty?

              start = entries.first[0]
              finish = entries.last[0] + entries.last[1].bytesize
              slice = normalized.slice(Tokens::Range::Normalized.new(start...finish))
              slice ? Tokens::Split.new(slice) : nil
            end
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "FixedLength"
          json.field "length", @length
        end
      end
    end
  end
end
