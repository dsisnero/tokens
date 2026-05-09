require "json"

module Tokens
  module Decoders
    struct ByteFallback
      include Tokens::Decoder

      def self.default : self
        new
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        new_tokens = [] of String
        previous_byte_tokens = [] of UInt8

        tokens.each do |token|
          byte = parse_byte_token(token)
          if byte
            previous_byte_tokens << byte
          else
            flush_previous_bytes(new_tokens, previous_byte_tokens)
            new_tokens << token
          end
        end

        flush_previous_bytes(new_tokens, previous_byte_tokens)
        new_tokens
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "ByteFallback"
        end
      end

      private def parse_byte_token(token : String) : UInt8?
        return nil unless token.bytesize == 6 && token.starts_with?("<0x") && token.ends_with?('>')

        hex = token.byte_slice(3, 2)
        return nil unless hex

        hex.to_i(16).to_u8
      rescue ArgumentError
        nil
      end

      private def flush_previous_bytes(new_tokens : Array(String), previous_byte_tokens : Array(UInt8))
        return if previous_byte_tokens.empty?

        bytes = Bytes.new(previous_byte_tokens.size) { |index| previous_byte_tokens[index] }
        candidate = String.new(bytes)
        if candidate.valid_encoding?
          new_tokens << candidate
        else
          previous_byte_tokens.size.times { new_tokens << "�" }
        end
        previous_byte_tokens.clear
      end
    end
  end
end
