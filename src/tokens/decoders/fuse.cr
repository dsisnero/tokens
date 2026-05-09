require "json"

module Tokens
  module Decoders
    struct Fuse
      include Tokens::Decoder

      def self.default : self
        new
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        [tokens.join("")]
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Fuse"
        end
      end
    end
  end
end
