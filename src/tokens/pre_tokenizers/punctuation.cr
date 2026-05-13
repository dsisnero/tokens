require "json"

module Tokens
  module PreTokenizers
    struct Punctuation
      include Tokens::PreTokenizer

      getter behavior : Tokens::SplitDelimiterBehavior

      PUNCTUATION_REGEX = Tokens::SysRegex.new("\\p{P}")

      def initialize(@behavior = Tokens::SplitDelimiterBehavior::Isolated)
      end

      def self.default : self
        new
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.split(->(char : Char) { punctuation?(char) }, @behavior)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Punctuation"
          json.field "behavior", @behavior.to_s
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(JSON::ParseException.new("Expected object", 0, 0))
        type = object["type"]?.try(&.as_s?)
        raise JSON::ParseException.new("Invalid pre-tokenizer type", 0, 0) if type && type != "Punctuation"

        behavior = object["behavior"]?.try(&.as_s?) || "Isolated"
        new(parse_behavior(behavior))
      end

      private def self.parse_behavior(value : String) : Tokens::SplitDelimiterBehavior
        case value
        when "Removed"
          Tokens::SplitDelimiterBehavior::Removed
        when "Isolated"
          Tokens::SplitDelimiterBehavior::Isolated
        when "MergedWithPrevious"
          Tokens::SplitDelimiterBehavior::MergedWithPrevious
        when "MergedWithNext"
          Tokens::SplitDelimiterBehavior::MergedWithNext
        when "Contiguous"
          Tokens::SplitDelimiterBehavior::Contiguous
        else
          raise JSON::ParseException.new("Invalid behavior", 0, 0)
        end
      end

      private def punctuation?(char : Char) : Bool
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
