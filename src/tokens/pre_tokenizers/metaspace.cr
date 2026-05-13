require "json"

module Tokens
  module PreTokenizers
    enum PrependScheme
      First
      Never
      Always
    end

    struct Metaspace
      include Tokens::PreTokenizer
      include Tokens::Decoder

      getter replacement : Char
      getter prepend_scheme : PrependScheme
      getter? split : Bool

      def initialize(@replacement = '▁', @prepend_scheme = PrependScheme::Always, @split = true)
      end

      def self.default : self
        new('▁', PrependScheme::Always, true)
      end

      # ameba:disable Naming/AccessorMethodName
      def get_replacement : Char
        @replacement
      end

      # ameba:disable Naming/AccessorMethodName
      def set_replacement(replacement : Char)
        @replacement = replacement
      end

      # ameba:disable Naming/AccessorMethodName
      def get_split : Bool
        @split
      end

      # ameba:disable Naming/AccessorMethodName
      def set_split(split : Bool)
        @split = split
      end

      # ameba:disable Naming/AccessorMethodName
      def get_prepend_scheme : PrependScheme
        @prepend_scheme
      end

      # ameba:disable Naming/AccessorMethodName
      def set_prepend_scheme(prepend_scheme : PrependScheme)
        @prepend_scheme = prepend_scheme
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        replacement = @replacement.to_s

        pretokenized.split do |_, normalized|
          normalized.replace(' ', replacement)

          case @prepend_scheme
          when PrependScheme::Always
            normalized.prepend(replacement) unless normalized.get.starts_with?(@replacement)
          when PrependScheme::First
            if !normalized.get.starts_with?(@replacement) && normalized.offsets_original[0] == 0
              normalized.prepend(replacement)
            end
          when PrependScheme::Never
          end

          if @split
            normalized.split(@replacement, Tokens::SplitDelimiterBehavior::MergedWithNext)
              .map { |slice| Tokens::Split.new(slice) }
          else
            [Tokens::Split.new(normalized)]
          end
        end
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        tokens.map_with_index do |token, index|
          String.build do |io|
            token.each_char do |char|
              if char == @replacement
                if index == 0 && @prepend_scheme != PrependScheme::Never
                  next
                end
                io << ' '
              else
                io << char
              end
            end
          end
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Metaspace"
          json.field "replacement", @replacement.to_s
          json.field "prepend_scheme", prepend_scheme_name(@prepend_scheme)
          json.field "split", @split
        end
      end

      def ==(other : self) : Bool
        @replacement == other.replacement &&
          @prepend_scheme == other.prepend_scheme &&
          @split == other.split?
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(JSON::ParseException.new("Expected object", 0, 0))
        raise JSON::ParseException.new("Invalid pre-tokenizer type", 0, 0) if object["type"]?.try(&.as_s?) && object["type"].as_s != "Metaspace"

        replacement = object["replacement"]?.try(&.as_s?)
        raise JSON::ParseException.new("Missing metaspace replacement", 0, 0) unless replacement

        add_prefix_space = object["add_prefix_space"]?.try(&.as_bool?)
        prepend_scheme = parse_prepend_scheme(object["prepend_scheme"]?.try(&.as_s?))
        if add_prefix_space == false && prepend_scheme != PrependScheme::Never
          raise JSON::ParseException.new("add_prefix_space does not match declared prepend_scheme", 0, 0)
        end

        prepend_scheme = PrependScheme::Never if add_prefix_space == false
        split = object["split"]?.try(&.as_bool?) || true
        new(replacement.each_char.first, prepend_scheme, split)
      end

      private def self.parse_prepend_scheme(value : String?) : PrependScheme
        case value
        when nil, "always"
          PrependScheme::Always
        when "first"
          PrependScheme::First
        when "never"
          PrependScheme::Never
        else
          raise JSON::ParseException.new("Invalid prepend_scheme", 0, 0)
        end
      end

      private def prepend_scheme_name(value : PrependScheme) : String
        case value
        when PrependScheme::Always
          "always"
        when PrependScheme::First
          "first"
        when PrependScheme::Never
          "never"
        else
          raise "Unsupported prepend scheme: #{value}"
        end
      end
    end
  end
end
