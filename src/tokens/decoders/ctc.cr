require "json"

module Tokens
  module Decoders
    struct CTC
      include Tokens::Decoder

      getter pad_token : String
      getter word_delimiter_token : String
      getter? cleanup : Bool

      def initialize(@pad_token : String, @word_delimiter_token : String, @cleanup : Bool)
      end

      def self.default : self
        new("<pad>", "|", true)
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        deduped = [] of String
        previous : String? = nil

        tokens.each do |token|
          next if previous == token
          deduped << token
          previous = token
        end

        deduped.compact_map do |token|
          replaced = token.gsub(@pad_token, "")
          if @cleanup
            replaced = Tokens::Decoders::WordPiece.cleanup(replaced).gsub(@word_delimiter_token, " ")
          end
          replaced.empty? ? nil : replaced
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "CTC"
          json.field "pad_token", @pad_token
          json.field "word_delimiter_token", @word_delimiter_token
          json.field "cleanup", @cleanup
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(Exception.new("Expected object"))
        type = object["type"]?.try(&.as_s?)
        raise Exception.new("Invalid decoder type") if type && type != "CTC"

        new(
          object["pad_token"]?.try(&.as_s?) || "<pad>",
          object["word_delimiter_token"]?.try(&.as_s?) || "|",
          object["cleanup"]?.try(&.as_bool?) != false,
        )
      end
    end
  end
end
