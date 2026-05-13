require "json"

module Tokens
  module Decoders
    class Sequence
      include Tokens::Decoder

      getter decoders : Array(Tokens::DecoderWrapper)

      def initialize(decoders : Array)
        @decoders = decoders.map do |decoder|
          case decoder
          when Tokens::DecoderWrapper
            decoder
          else
            Tokens::DecoderWrapper.from(decoder)
          end
        end
      end

      # ameba:disable Naming/AccessorMethodName
      def get_decoders : Array(Tokens::DecoderWrapper)
        @decoders
      end

      # ameba:disable Naming/AccessorMethodName
      def get_decoders_mut : Array(Tokens::DecoderWrapper)
        @decoders
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        @decoders.reduce(tokens) { |current, decoder| decoder.decode_chain(current) }
      end

      def ==(other : self) : Bool
        @decoders == other.decoders
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Sequence"
          json.field "decoders" do
            json.array do
              @decoders.each(&.to_json(json))
            end
          end
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(Exception.new("Expected object"))
        type = object["type"]?.try(&.as_s?)
        raise Exception.new("Invalid decoder type") if type && type != "Sequence"

        decoders = object["decoders"]?
        raise Exception.new("missing field `decoders`") unless decoders

        new(decoders.as_a.map { |entry| Tokens::DecoderWrapper.from_json(entry) })
      end
    end
  end
end
