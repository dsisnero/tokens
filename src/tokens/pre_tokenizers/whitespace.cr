module Tokens
  module PreTokenizers
    struct Whitespace
      include Tokens::PreTokenizer

      REGEX = Tokens::SysRegex.new("\\w+|[^\\w\\s]+")

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.split(Tokens::Invert.new(REGEX), Tokens::SplitDelimiterBehavior::Removed)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Whitespace"
        end
      end
    end

    struct WhitespaceSplit
      include Tokens::PreTokenizer

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.split(->(char : Char) { char.whitespace? }, Tokens::SplitDelimiterBehavior::Removed)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end
    end
  end
end
