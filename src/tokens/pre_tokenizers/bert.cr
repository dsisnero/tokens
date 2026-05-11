require "unicode"

module Tokens
  module PreTokenizers
    struct BertPreTokenizer
      include Tokens::PreTokenizer

      PUNCTUATION_REGEX = Tokens::SysRegex.new("\\p{P}")

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.split(->(char : Char) { char.whitespace? }, Tokens::SplitDelimiterBehavior::Removed)
            .map { |slice| Tokens::Split.new(slice) }
        end

        pretokenized.split do |_, normalized|
          normalized.split(->(char : Char) { bert_punctuation?(char) }, Tokens::SplitDelimiterBehavior::Isolated)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "BertPreTokenizer"
        end
      end

      private def bert_punctuation?(char : Char) : Bool
        code = char.ord
        ascii_punctuation = (33..47).includes?(code) ||
                            (58..64).includes?(code) ||
                            (91..96).includes?(code) ||
                            (123..126).includes?(code)

        ascii_punctuation || !PUNCTUATION_REGEX.find_iter(char.to_s).empty?
      end
    end
  end
end
