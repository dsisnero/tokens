require "json"

module Tokens
  module Decoders
    struct BPEDecoder
      include Tokens::Decoder

      getter suffix : String

      def initialize(@suffix : String)
      end

      def self.default : self
        new("</w>")
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        last_index = tokens.size - 1
        tokens.map_with_index do |token, index|
          replacement = index == last_index ? "" : " "
          token.gsub(@suffix, replacement)
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "BPEDecoder"
          json.field "suffix", @suffix
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(Exception.new("Expected object"))
        type = object["type"]?.try(&.as_s?)
        raise Exception.new("Invalid decoder type") if type && type != "BPEDecoder"
        new(object["suffix"]?.try(&.as_s?) || "</w>")
      end
    end
  end
end
