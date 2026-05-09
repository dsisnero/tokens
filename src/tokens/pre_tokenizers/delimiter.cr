require "json"

module Tokens
  module PreTokenizers
    struct CharDelimiterSplit
      include Tokens::PreTokenizer

      getter delimiter : Char

      def initialize(@delimiter : Char)
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.split(@delimiter, Tokens::SplitDelimiterBehavior::Removed)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Delimiter"
          json.field "delimiter", @delimiter.to_s
        end
      end
    end
  end
end
