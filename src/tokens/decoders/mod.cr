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

    private def self.from_any(value : JSON::Any) : self
      object = value.as_h?
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged") unless object

      type = object["type"]?.try(&.as_s?)
      raise Exception.new("data did not match any variant of untagged enum DecoderUntagged") unless type

      from_tagged(type, object)
    end

    private def self.from_tagged(type : String, object : Hash(String, JSON::Any)) : self
      case type
      when "BPEDecoder"
        new(Tokens::Decoders::BPEDecoder.from_json(object.to_json))
      when "ByteLevel"
        new(Tokens::PreTokenizers::ByteLevel.from_json(object.to_json))
      when "WordPiece"
        new(Tokens::Decoders::WordPiece.from_json(object.to_json))
      when "Metaspace"
        new(Tokens::PreTokenizers::Metaspace.from_json(object.to_json))
      when "CTC"
        new(Tokens::Decoders::CTC.from_json(object.to_json))
      when "Sequence"
        new(Tokens::Decoders::Sequence.from_json(object.to_json))
      when "Replace"
        new(Tokens::Normalizers::Replace.from_json(JSON::PullParser.new(object.to_json)))
      when "Fuse"
        new(Tokens::Decoders::Fuse.new)
      when "Strip"
        new(Tokens::Decoders::Strip.from_json(object.to_json))
      when "ByteFallback"
        new(Tokens::Decoders::ByteFallback.new)
      else
        raise Exception.new("data did not match any variant of untagged enum DecoderUntagged")
      end
    end
  end
end
