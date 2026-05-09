require "json"

module Tokens
  module Decoders
    struct WordPiece
      include Tokens::Decoder

      getter prefix : String
      getter? cleanup : Bool

      def initialize(@prefix : String, @cleanup : Bool)
      end

      def self.default : self
        new("##", true)
      end

      def self.cleanup(dirty_input : String) : String
        dirty_input
          .gsub(" .", ".")
          .gsub(" ?", "?")
          .gsub(" !", "!")
          .gsub(" ,", ",")
          .gsub(" ' ", "'")
          .gsub(" n't", "n't")
          .gsub(" 'm", "'m")
          .gsub(" do not", " don't")
          .gsub(" 's", "'s")
          .gsub(" 've", "'ve")
          .gsub(" 're", "'re")
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        tokens.map_with_index do |token, index|
          updated = if index != 0
                      if token.starts_with?(@prefix)
                        token.byte_slice(@prefix.bytesize, token.bytesize - @prefix.bytesize) || ""
                      else
                        " #{token}"
                      end
                    else
                      token
                    end
          @cleanup ? self.class.cleanup(updated) : updated
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "WordPiece"
          json.field "prefix", @prefix
          json.field "cleanup", @cleanup
        end
      end

      def self.from_json(json : String) : self
        object = JSON.parse(json).as_h
        type = object["type"]?.try(&.as_s?)
        raise Exception.new("Invalid decoder type") if type && type != "WordPiece"

        new(
          object["prefix"]?.try(&.as_s?) || "##",
          object["cleanup"]?.try(&.as_bool?) != false,
        )
      end
    end
  end
end
