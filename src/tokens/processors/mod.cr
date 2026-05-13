require "json"

module Tokens
  class PostProcessorWrapper
    alias Wrapped = Tokens::PostProcessors::BertProcessing |
                    Tokens::PostProcessors::RobertaProcessing |
                    Tokens::PreTokenizers::ByteLevel |
                    Tokens::PostProcessors::TemplateProcessing |
                    Tokens::PostProcessors::SequenceProcessor

    include Tokens::PostProcessor

    getter processor : Wrapped

    def initialize(@processor : Wrapped)
    end

    def self.from(processor : Wrapped) : self
      new(processor)
    end

    def added_tokens(is_pair : Bool) : Int32
      @processor.added_tokens(is_pair)
    end

    def process(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding?, add_special_tokens : Bool) : Tokens::Encoding
      @processor.process(encoding, pair_encoding, add_special_tokens)
    end

    def ==(other : self) : Bool
      @processor == other.processor
    end

    def to_json(json : JSON::Builder)
      @processor.to_json(json)
    end

    def self.from_json(json_str : String) : self
      from_json(JSON.parse(json_str))
    end

    def self.from_json(data : JSON::Any) : self
      raise Exception.new("data did not match any variant of untagged enum PostProcessorWrapper") unless data.as_h?
      obj = data.as_h

      if type = obj["type"]?.try(&.as_s?)
        return from_tagged(type, data)
      end

      from_untagged(data)
    end

    private def self.from_tagged(type : String, data : JSON::Any) : self
      begin
        case type
        when "RobertaProcessing"
          return new(Tokens::PostProcessors::RobertaProcessing.from_json(data))
        when "BertProcessing"
          return new(Tokens::PostProcessors::BertProcessing.from_json(data))
        when "ByteLevel"
          return new(Tokens::PreTokenizers::ByteLevel.from_json(data))
        when "TemplateProcessing"
          return new(Tokens::PostProcessors::TemplateProcessing.from_json(data))
        when "Sequence"
          return new(Tokens::PostProcessors::SequenceProcessor.from_json(data))
        end
      rescue
      end

      raise Exception.new("data did not match any variant of untagged enum PostProcessorWrapper")
    end

    private def self.from_untagged(data : JSON::Any) : self
      # Only Roberta and Bert can match without a type tag (fields-only matching)
      # Roberta must come before Bert, but Roberta requires trim_offsets + add_prefix_space fields

      # Try Roberta (fields-only, no type check)
      begin
        return new(Tokens::PostProcessors::RobertaProcessing.from_json(data, check_type: false))
      rescue
      end

      # Try Bert (fields-only, no type check)
      begin
        return new(Tokens::PostProcessors::BertProcessing.from_json(data, check_type: false))
      rescue
      end

      raise Exception.new("data did not match any variant of untagged enum PostProcessorWrapper")
    end
  end
end
