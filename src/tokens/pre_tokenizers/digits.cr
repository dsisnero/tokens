require "json"

module Tokens
  module PreTokenizers
    struct Digits
      include Tokens::PreTokenizer

      getter? individual_digits : Bool

      def initialize(@individual_digits = false)
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        behavior = @individual_digits ? Tokens::SplitDelimiterBehavior::Isolated : Tokens::SplitDelimiterBehavior::Contiguous

        pretokenized.split do |_, normalized|
          normalized.split(->(char : Char) { char.number? }, behavior)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Digits"
          json.field "individual_digits", @individual_digits
        end
      end
    end
  end
end
