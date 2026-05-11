require "json"

module Tokens
  class NormalizerWrapper
    alias Wrapped = Tokens::Normalizers::BertNormalizer |
                    Tokens::Normalizers::Strip |
                    Tokens::Normalizers::StripAccents |
                    Tokens::Normalizers::NFC |
                    Tokens::Normalizers::NFD |
                    Tokens::Normalizers::NFKC |
                    Tokens::Normalizers::NFKD |
                    Tokens::Normalizers::Sequence |
                    Tokens::Normalizers::Lowercase |
                    Tokens::Normalizers::Nmt |
                    Tokens::Normalizers::Precompiled |
                    Tokens::Normalizers::Replace |
                    Tokens::Normalizers::Prepend |
                    Tokens::Normalizers::ByteLevel

    include Tokens::Normalizer

    getter normalizer : Wrapped

    def initialize(@normalizer : Wrapped)
    end

    def self.from(normalizer : Wrapped) : self
      new(normalizer)
    end

    def normalize(normalized : Tokens::NormalizedString) : Nil
      @normalizer.normalize(normalized)
    end

    def to_json(json : JSON::Builder)
      @normalizer.to_json(json)
    end

    def ==(other : self) : Bool
      @normalizer == other.normalizer
    end

    def self.from_json(json : String) : self
      from_any(JSON.parse(json))
    end

    private def self.from_any(value : JSON::Any) : self
      object = value.as_h?
      raise Exception.new("data did not match any variant of untagged enum NormalizerUntagged") unless object

      if type = object["type"]?.try(&.as_s?)
        return from_tagged(type, object)
      end

      if legacy_strip?(object)
        return new(Tokens::Normalizers::Strip.new(
          object["strip_left"]?.try(&.as_bool) || false,
          object["strip_right"]?.try(&.as_bool) || false,
        ))
      end

      if object.size == 1 && object["prepend"]?
        return new(Tokens::Normalizers::Prepend.new(object["prepend"].as_s))
      end

      raise Exception.new("data did not match any variant of untagged enum NormalizerUntagged")
    end

    private def self.from_tagged(type : String, object : Hash(String, JSON::Any)) : self
      case type
      when "BertNormalizer"
        new(build_bert_normalizer(object))
      when "Strip"
        new(build_strip_normalizer(object))
      when "StripAccents"
        new(Tokens::Normalizers::StripAccents.new)
      when "NFC", "NFD", "NFKC", "NFKD", "Lowercase", "Nmt", "Precompiled", "ByteLevel"
        build_unit_wrapper(type)
      when "Replace"
        new(Tokens::Normalizers::Replace.from_json(object.to_json))
      when "Prepend"
        new(Tokens::Normalizers::Prepend.new(object["prepend"]?.try(&.as_s) || ""))
      when "Sequence"
        build_sequence_wrapper(object)
      else
        raise Exception.new("data did not match any variant of untagged enum NormalizerUntagged")
      end
    end

    private def self.legacy_strip?(object : Hash(String, JSON::Any)) : Bool
      object.size > 0 && object.keys.all? { |key| key == "strip_left" || key == "strip_right" }
    end

    private def self.build_bert_normalizer(object : Hash(String, JSON::Any)) : Tokens::Normalizers::BertNormalizer
      Tokens::Normalizers::BertNormalizer.new(
        clean_text: object["clean_text"]?.try(&.as_bool) || false,
        handle_chinese_chars: object["handle_chinese_chars"]?.try(&.as_bool) || false,
        strip_accents: nullable_bool(object["strip_accents"]?),
        lowercase: object["lowercase"]?.try(&.as_bool) || false,
      )
    end

    private def self.build_strip_normalizer(object : Hash(String, JSON::Any)) : Tokens::Normalizers::Strip
      Tokens::Normalizers::Strip.new(
        object["strip_left"]?.try(&.as_bool) || false,
        object["strip_right"]?.try(&.as_bool) || false,
      )
    end

    private def self.build_sequence_wrapper(object : Hash(String, JSON::Any)) : self
      normalizers = object["normalizers"]?
      raise Exception.new("missing field `normalizers`") unless normalizers

      array = normalizers.as_a
      new(Tokens::Normalizers::Sequence.new(array.map { |entry| from_any(entry) }))
    end

    private def self.build_unit_wrapper(type : String) : self
      case type
      when "NFC"
        new(Tokens::Normalizers::NFC.new)
      when "NFD"
        new(Tokens::Normalizers::NFD.new)
      when "NFKC"
        new(Tokens::Normalizers::NFKC.new)
      when "NFKD"
        new(Tokens::Normalizers::NFKD.new)
      when "Lowercase"
        new(Tokens::Normalizers::Lowercase.new)
      when "Nmt"
        new(Tokens::Normalizers::Nmt.new)
      when "Precompiled"
        new(Tokens::Normalizers::Precompiled.new)
      when "ByteLevel"
        new(Tokens::Normalizers::ByteLevel.new)
      else
        raise Exception.new("data did not match any variant of untagged enum NormalizerUntagged")
      end
    end

    private def self.nullable_bool(value : JSON::Any?) : Bool?
      return nil unless value
      return nil if value.raw.nil?

      value.as_bool
    end
  end
end
