require "json"
require "set"

module Tokens
  module PreTokenizers
    class ByteLevel
      include Tokens::PreTokenizer
      include Tokens::Decoder
      include Tokens::PostProcessor

      GPT2_REGEX = Tokens::SysRegex.new("'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+")

      @@char_bytes : Hash(Char, UInt8)?

      getter? add_prefix_space : Bool
      getter? trim_offsets : Bool
      getter? use_regex : Bool

      def initialize(@add_prefix_space = true, @trim_offsets = true, @use_regex = true)
      end

      def self.default : self
        new(true, true, true)
      end

      def self.alphabet : Set(Char)
        alphabet = Set(Char).new
        Tokens::Normalizers::ByteLevel.bytes_char.each_value { |char| alphabet << char }
        alphabet
      end

      def add_prefix_space(value : Bool) : self
        self.class.new(value, @trim_offsets, @use_regex)
      end

      def trim_offsets(value : Bool) : self
        self.class.new(@add_prefix_space, value, @use_regex)
      end

      def use_regex(value : Bool) : self
        self.class.new(@add_prefix_space, @trim_offsets, value)
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          normalized.prepend(" ") if @add_prefix_space && !normalized.get.starts_with?(' ')

          if @use_regex
            normalized.split(GPT2_REGEX, Tokens::SplitDelimiterBehavior::Isolated)
              .map { |slice| Tokens::Split.new(slice) }
          else
            [Tokens::Split.new(normalized)]
          end
        end

        pretokenized.normalize do |normalized|
          raw = normalized.get
          transformations = Array({Char, Int32}).new(raw.bytesize)
          raw.each_byte do |byte|
            change = (byte & 0xC0) == 0x80 ? 1 : 0
            transformations << {Tokens::Normalizers::ByteLevel.bytes_char[byte], change}
          end
          normalized.transform(transformations, 0)
        end
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        bytes = [] of UInt8

        tokens.each do |token|
          token_bytes = token.each_char.compact_map { |char| self.class.char_bytes[char]? }.to_a
          if token_bytes.size == token.chars.size
            bytes.concat(token_bytes)
          else
            bytes.concat(token.to_slice.to_a)
          end
        end

        [String.build { |io| bytes.each { |byte| io.write_byte(byte) } }]
      end

      def added_tokens(is_pair : Bool) : Int32
        0
      end

      def process(
        encoding : Tokens::Encoding,
        pair_encoding : Tokens::Encoding?,
        add_special_tokens : Bool,
      ) : Tokens::Encoding
        encodings = if pair = pair_encoding
                      [encoding, pair]
                    else
                      [encoding]
                    end

        prepared = encodings.map_with_index do |item, index|
          if @trim_offsets
            Tokens::PreTokenizers.process_offsets(item, @add_prefix_space)
            item.overflowing.each { |overflow| Tokens::PreTokenizers.process_offsets(overflow, @add_prefix_space) }
          end

          item.set_sequence_id(index.to_u64)
          item.set_type_ids(Array(UInt32).new(item.length, index.to_u32))
          item.overflowing.each do |overflow|
            overflow.set_sequence_id(index.to_u64)
            overflow.set_type_ids(Array(UInt32).new(overflow.length, index.to_u32))
          end
          item
        end

        return prepared[0] if prepared.size == 1

        Tokens::Encoding.merge(prepared, false)
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "ByteLevel"
          json.field "add_prefix_space", @add_prefix_space
          json.field "trim_offsets", @trim_offsets
          json.field "use_regex", @use_regex
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(JSON::ParseException.new("Expected object", 0, 0))
        type = object["type"]?.try(&.as_s?)
        raise JSON::ParseException.new("Invalid pre-tokenizer type", 0, 0) if type && type != "ByteLevel"

        new(
          object["add_prefix_space"]?.try(&.as_bool) || false,
          object["trim_offsets"]?.try(&.as_bool) || false,
          object["use_regex"]?.try(&.as_bool?) != false,
        )
      end

      def self.char_bytes : Hash(Char, UInt8)
        @@char_bytes ||= begin
          map = {} of Char => UInt8
          Tokens::Normalizers::ByteLevel.bytes_char.each do |byte, char|
            map[char] = byte
          end
          map
        end
      end
    end

    def self.process_offsets(encoding : Tokens::Encoding, add_prefix_space : Bool)
      byte_space = Tokens::Normalizers::ByteLevel.bytes_char[' '.ord.to_u8]

      encoding.process_tokens_with_offsets_mut do |index, token, offsets|
        leading_spaces = count_leading_spaces(token, byte_space)
        trailing_spaces = count_trailing_spaces(token, byte_space)

        updated = offsets
        if leading_spaces > 0 || trailing_spaces > 0
          if leading_spaces > 0
            is_first = index == 0 || offsets[0] == 0
            leading_spaces = 0 if is_first && add_prefix_space && leading_spaces == 1
            updated = {Math.min(offsets[0] + leading_spaces.to_u32, offsets[1]), updated[1]}
          end

          if trailing_spaces > 0 && updated[1] >= trailing_spaces
            updated = {updated[0], Math.max(updated[1] - trailing_spaces.to_u32, updated[0])}
          end
        end

        updated
      end
    end

    private def self.count_leading_spaces(token : String, byte_space : Char) : Int32
      count = 0
      reader = Char::Reader.new(token)
      while reader.has_next?
        char = reader.current_char
        break unless char == byte_space || char.whitespace?
        count += 1
        reader.next_char?
      end
      count
    end

    private def self.count_trailing_spaces(token : String, byte_space : Char) : Int32
      count = 0
      reader = Char::Reader.new(at_end: token)
      while reader.current_char != '\0'
        char = reader.current_char
        break unless char == byte_space || char.whitespace?
        count += 1
        break unless reader.has_previous?
        reader.previous_char?
      end
      count
    end
  end
end
