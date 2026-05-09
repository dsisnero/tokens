require "json"

module Tokens
  class PreTokenizerWrapper
    alias Wrapped = Tokens::PreTokenizers::BertPreTokenizer |
                    Tokens::PreTokenizers::ByteLevel |
                    Tokens::PreTokenizers::CharDelimiterSplit |
                    Tokens::PreTokenizers::Digits |
                    Tokens::PreTokenizers::FixedLength |
                    Tokens::PreTokenizers::Metaspace |
                    Tokens::PreTokenizers::Punctuation |
                    Tokens::PreTokenizers::Sequence |
                    Tokens::PreTokenizers::Split |
                    Tokens::PreTokenizers::UnicodeScripts |
                    Tokens::PreTokenizers::Whitespace |
                    Tokens::PreTokenizers::WhitespaceSplit

    include Tokens::PreTokenizer

    getter pretokenizer : Wrapped

    def initialize(@pretokenizer : Wrapped)
    end

    def self.from(pretokenizer : Wrapped) : self
      new(pretokenizer)
    end

    def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
      @pretokenizer.pre_tokenize(pretokenized)
    end

    def ==(other : self) : Bool
      @pretokenizer == other.pretokenizer
    end

    def self.from_json(json : String) : self
      from_any(JSON.parse(json))
    rescue JSON::ParseException
      raise Exception.new("data did not match any variant of untagged enum PreTokenizerUntagged")
    end

    private def self.from_any(value : JSON::Any) : self
      object = value.as_h?
      raise Exception.new("data did not match any variant of untagged enum PreTokenizerUntagged") unless object

      if type = object["type"]?.try(&.as_s?)
        return from_tagged(type, object)
      end

      raise Exception.new("data did not match any variant of untagged enum PreTokenizerUntagged")
    end

    private def self.from_tagged(type : String, object : Hash(String, JSON::Any)) : self
      if pretokenizer = build_unit_pretokenizer(type)
        return new(pretokenizer)
      end

      new(build_complex_pretokenizer(type, object))
    end

    private def self.build_unit_pretokenizer(type : String) : Wrapped?
      case type
      when "BertPreTokenizer"
        Tokens::PreTokenizers::BertPreTokenizer.new
      when "Whitespace"
        Tokens::PreTokenizers::Whitespace.new
      when "WhitespaceSplit"
        Tokens::PreTokenizers::WhitespaceSplit.new
      when "UnicodeScripts"
        Tokens::PreTokenizers::UnicodeScripts.new
      else
        nil
      end
    end

    private def self.build_complex_pretokenizer(type : String, object : Hash(String, JSON::Any)) : Wrapped
      case type
      when "Delimiter"
        build_delimiter(object)
      when "ByteLevel"
        Tokens::PreTokenizers::ByteLevel.from_json(object.to_json)
      when "Digits"
        Tokens::PreTokenizers::Digits.new(object["individual_digits"]?.try(&.as_bool) || false)
      when "FixedLength"
        Tokens::PreTokenizers::FixedLength.new(object["length"]?.try(&.as_i) || 5)
      when "Metaspace"
        build_metaspace(object)
      when "Punctuation"
        Tokens::PreTokenizers::Punctuation.from_json(object.to_json)
      when "Sequence"
        build_sequence(object)
      when "Split"
        Tokens::PreTokenizers::Split.from_json(object.to_json)
      else
        raise Exception.new("data did not match any variant of untagged enum PreTokenizerUntagged")
      end
    end

    private def self.build_delimiter(object : Hash(String, JSON::Any)) : Wrapped
      delimiter = object["delimiter"]?.try(&.as_s?) || raise(Exception.new("missing field `delimiter`"))
      Tokens::PreTokenizers::CharDelimiterSplit.new(delimiter.each_char.first)
    end

    private def self.build_metaspace(object : Hash(String, JSON::Any)) : Wrapped
      replacement = object["replacement"]?.try(&.as_s?)
      raise Exception.new("missing field `replacement`") unless replacement

      add_prefix_space = object["add_prefix_space"]?.try(&.as_bool?)
      prepend_scheme = parse_prepend_scheme(object["prepend_scheme"]?.try(&.as_s?))
      if add_prefix_space == false && prepend_scheme != Tokens::PreTokenizers::PrependScheme::Never
        raise Exception.new("add_prefix_space does not match declared prepend_scheme")
      end
      prepend_scheme = Tokens::PreTokenizers::PrependScheme::Never if add_prefix_space == false

      Tokens::PreTokenizers::Metaspace.new(
        replacement.each_char.first,
        prepend_scheme,
        object["split"]?.try(&.as_bool?) || true,
      )
    end

    private def self.build_sequence(object : Hash(String, JSON::Any)) : Wrapped
      pretokenizers = object["pretokenizers"]?
      raise Exception.new("missing field `pretokenizers`") unless pretokenizers

      Tokens::PreTokenizers::Sequence.new(pretokenizers.as_a.map { |entry| from_any(entry) })
    end

    private def self.parse_prepend_scheme(value : String?) : Tokens::PreTokenizers::PrependScheme
      case value
      when nil, "always"
        Tokens::PreTokenizers::PrependScheme::Always
      when "first"
        Tokens::PreTokenizers::PrependScheme::First
      when "never"
        Tokens::PreTokenizers::PrependScheme::Never
      else
        raise Exception.new("invalid prepend_scheme")
      end
    end
  end
end
