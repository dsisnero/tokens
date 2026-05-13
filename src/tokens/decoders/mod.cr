require "json"

module Tokens
  class DecoderWrapper
    alias Wrapped = Tokens::Decoders::BPEDecoder |
                    Tokens::PreTokenizers::ByteLevel |
                    Tokens::Decoders::WordPiece |
                    Tokens::PreTokenizers::Metaspace |
                    Tokens::Decoders::CTC |
                    Tokens::Decoders::Sequence |
                    Tokens::Normalizers::Replace |
                    Tokens::Decoders::Fuse |
                    Tokens::Decoders::Strip |
                    Tokens::Decoders::ByteFallback

    include Tokens::Decoder

    getter decoder : Wrapped

    def initialize(@decoder : Wrapped)
    end

    def self.from(decoder : Wrapped) : self
      new(decoder)
    end

    def ==(other : self) : Bool
      @decoder == other.decoder
    end

    def decode_chain(tokens : Array(String)) : Array(String)
      @decoder.decode_chain(tokens)
    end

    def to_json(json : JSON::Builder)
      @decoder.to_json(json)
    end

    def self.from_json(json : String) : self
      from_any(JSON.parse(json))
    rescue JSON::ParseException
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged")
    end

    def self.from_json(value : JSON::Any) : self
      from_any(value)
    rescue JSON::ParseException
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged")
    end

    private def self.from_any(value : JSON::Any) : self
      object = value.as_h?
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged") unless object

      type = object["type"]?.try(&.as_s?)
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged") unless type

      from_tagged(type, value)
    end

    private def self.from_tagged(type : String, value : JSON::Any) : self
      case type
      when "BPEDecoder"
        new(Tokens::Decoders::BPEDecoder.from_json(value))
      when "ByteLevel"
        new(Tokens::PreTokenizers::ByteLevel.from_json(value))
      when "WordPiece"
        new(Tokens::Decoders::WordPiece.from_json(value))
      when "Metaspace"
        new(Tokens::PreTokenizers::Metaspace.from_json(value))
      when "CTC"
        new(Tokens::Decoders::CTC.from_json(value))
      when "Sequence"
        new(Tokens::Decoders::Sequence.from_json(value))
      when "Replace"
        new(Tokens::Normalizers::Replace.from_json(value))
      when "Fuse"
        new(Tokens::Decoders::Fuse.new)
      when "Strip"
        new(Tokens::Decoders::Strip.from_json(value))
      when "ByteFallback"
        new(Tokens::Decoders::ByteFallback.new)
      else
        raise Exception.new("data did not match any variant of untagged enum DecoderUntagged")
      end
    end
  end
end
