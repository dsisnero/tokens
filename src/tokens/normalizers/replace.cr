require "json"

module Tokens
  module Normalizers
    struct ReplacePattern
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

      def self.from_json(pull : JSON::PullParser) : self
        kind = nil
        value = nil

        pull.read_begin_object
        until pull.kind.end_object?
          key = pull.read_object_key
          case key
          when "String"
            kind = Kind::String
            value = pull.read_string
          when "Regex"
            kind = Kind::Regex
            value = pull.read_string
          else
            pull.skip
          end
        end
        pull.read_end_object

        raise JSON::ParseException.new("Missing ReplacePattern kind", 0, 0) unless kind
        raise JSON::ParseException.new("Missing ReplacePattern value", 0, 0) unless value
        new(value, kind)
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(JSON::ParseException.new("Expected object", 0, 0))

        if string = object["String"]?.try(&.as_s?)
          return string(string)
        end
        if regex = object["Regex"]?.try(&.as_s?)
          return regex(regex)
        end

        raise JSON::ParseException.new("Missing ReplacePattern kind", 0, 0)
      end

      def self.new(pull : JSON::PullParser) : self
        from_json(pull)
      end
    end

    struct Replace
      include Tokens::Normalizer
      include Tokens::Decoder

      getter pattern : ReplacePattern
      getter content : String
      @regex : Tokens::SysRegex

      def initialize(pattern : ReplacePattern, @content : String)
        @pattern = pattern
        regex = case pattern.kind
                when ReplacePattern::Kind::String
                  Tokens::SysRegex.new(Regex.escape(pattern.value))
                when ReplacePattern::Kind::Regex
                  Tokens::SysRegex.new(pattern.value)
                else
                  raise "Unsupported ReplacePattern kind: #{pattern.kind}"
                end
        @regex = regex
      end

      def initialize(pattern : ReplacePattern, content : Char)
        initialize(pattern, content.to_s)
      end

      def initialize(pattern : String, content : String | Char)
        initialize(ReplacePattern.string(pattern), content.to_s)
      end

      def ==(other : self) : Bool
        @pattern == other.pattern && @content == other.content
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.replace(@regex, @content)
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        tokens.map do |token|
          String.build do |io|
            @regex.find_matches(token).each do |(offsets, is_match)|
              start = offsets[0].to_i
              stop = offsets[1].to_i

              if is_match
                io << @content
              else
                io << (token.byte_slice(start, stop - start) || "")
              end
            end
          end
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Replace"
          json.field "pattern", @pattern
          json.field "content", @content
        end
      end

      def self.from_json(pull : JSON::PullParser) : self
        type = nil
        pattern = nil
        content = nil

        pull.read_begin_object
        until pull.kind.end_object?
          key = pull.read_object_key
          case key
          when "type"
            type = pull.read_string
          when "pattern"
            pattern = ReplacePattern.from_json(pull)
          when "content"
            content = pull.read_string
          else
            pull.skip
          end
        end
        pull.read_end_object

        raise JSON::ParseException.new("Invalid normalizer type", 0, 0) if type && type != "Replace"
        raise JSON::ParseException.new("Missing Replace pattern", 0, 0) unless pattern
        raise JSON::ParseException.new("Missing Replace content", 0, 0) unless content

        new(pattern, content)
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(JSON::ParseException.new("Expected object", 0, 0))
        type = object["type"]?.try(&.as_s?)
        raise JSON::ParseException.new("Invalid normalizer type", 0, 0) if type && type != "Replace"

        pattern_json = object["pattern"]? || raise(JSON::ParseException.new("Missing Replace pattern", 0, 0))
        content = object["content"]?.try(&.as_s?) || raise(JSON::ParseException.new("Missing Replace content", 0, 0))

        new(ReplacePattern.from_json(pattern_json), content)
      end

      def self.new(pull : JSON::PullParser) : self
        from_json(pull)
      end
    end
  end
end
