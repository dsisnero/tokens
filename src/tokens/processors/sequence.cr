require "json"

module Tokens
  module PostProcessors
    class SequenceProcessor
      include Tokens::PostProcessor

      getter processors : Array(PostProcessorWrapper)

      def initialize(@processors : Array(PostProcessorWrapper) = [] of PostProcessorWrapper)
      end

      def get(index : Int32) : PostProcessorWrapper?
        @processors[index]?
      end

      def get_mut(index : Int32) : PostProcessorWrapper?
        @processors[index]?
      end

      def set_mut(index : Int32, post_proc : PostProcessorWrapper)
        @processors[index] = post_proc
      end

      def added_tokens(is_pair : Bool) : Int32
        @processors.sum { |p| p.added_tokens(is_pair) }
      end

      def process(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding?, add_special_tokens : Bool) : Tokens::Encoding
        result = encoding
        curr_pair = pair_encoding

        @processors.each do |processor|
          result = processor.process(result, curr_pair, add_special_tokens)
          # After the first processor merges encodings, the pair becomes nil
          curr_pair = nil
        end

        result
      end

      def ==(other : self) : Bool
        @processors == other.processors
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Sequence"
          json.field "processors" do
            json.array do
              @processors.each do |proc|
                proc.to_json(json)
              end
            end
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
        obj = data.as_h

        procs_arr = obj["processors"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing processors", 0, 0))
        processors = procs_arr.map do |item|
          PostProcessorWrapper.from_json(item.to_json)
        end

        new(processors)
      end
    end
  end
end
