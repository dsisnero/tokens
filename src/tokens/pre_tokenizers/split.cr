require "json"

module Tokens
  module PreTokenizers
    struct SplitPattern
      enum Kind
        String
        Regex
      end

      getter value : String
      getter kind : Kind

      def initialize(@value : String, @kind : Kind)
      end

      def self.string(value : String) : self
        new(value, Kind::String)
      end

      def self.regex(value : String) : self
        new(value, Kind::Regex)
      end

      def ==(other : self) : Bool
        @value == other.value && @kind == other.kind
      end

      def to_json(json : JSON::Builder)
        json.object do
          case @kind
          when Kind::String
            json.field "String", @value
          when Kind::Regex
            json.field "Regex", @value
          end
        end
      end

      def self.from_any(value : JSON::Any) : self
        object = value.as_h
        if string = object["String"]?.try(&.as_s?)
          return string(string)
        end
        if regex = object["Regex"]?.try(&.as_s?)
          return regex(regex)
        end
        raise JSON::ParseException.new("Invalid split pattern", 0, 0)
      end
    end

    class Split
      include Tokens::PreTokenizer

      getter pattern : SplitPattern
      getter behavior : Tokens::SplitDelimiterBehavior
      getter? invert : Bool
      @regex : Tokens::SysRegex

      def initialize(pattern : String, behavior : Tokens::SplitDelimiterBehavior, invert : Bool)
        initialize(SplitPattern.string(pattern), behavior, invert)
      end

      def initialize(@pattern : SplitPattern, @behavior : Tokens::SplitDelimiterBehavior, @invert : Bool)
        source = case @pattern.kind
                 when SplitPattern::Kind::String
                   Regex.escape(@pattern.value)
                 when SplitPattern::Kind::Regex
                   @pattern.value
                 end
        @regex = Tokens::SysRegex.new(source.as(String))
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pattern = @invert ? Tokens::Invert.new(@regex) : @regex

        pretokenized.split do |_, normalized|
          normalized.split(pattern, @behavior)
            .map { |slice| Tokens::Split.new(slice) }
        end
      end

      def ==(other : self) : Bool
        @pattern == other.pattern &&
          @behavior == other.behavior &&
          @invert == other.invert?
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Split"
          json.field "pattern", @pattern
          json.field "behavior", @behavior.to_s
          json.field "invert", @invert
        end
      end

      def self.from_json(json : String) : self
        object = JSON.parse(json).as_h
        type = object["type"]?.try(&.as_s?)
        raise JSON::ParseException.new("Invalid pre-tokenizer type", 0, 0) if type && type != "Split"

        pattern = object["pattern"]? ? SplitPattern.from_any(object["pattern"]) : raise(JSON::ParseException.new("Missing split pattern", 0, 0))
        behavior = parse_behavior(object["behavior"]?.try(&.as_s?) || raise(JSON::ParseException.new("Missing split behavior", 0, 0)))
        invert = object["invert"]?.try(&.as_bool?) || false
        new(pattern, behavior, invert)
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
    end
  end
end
