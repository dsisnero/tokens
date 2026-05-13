require "json"

module Tokens
  module Decoders
    struct Strip
      include Tokens::Decoder

      getter content : Char
      getter start : Int32
      getter stop : Int32

      def initialize(@content : Char, @start : Int32, @stop : Int32)
      end

      def decode_chain(tokens : Array(String)) : Array(String)
        tokens.map do |token|
          chars = token.chars

          start_cut = 0
          0.upto(Math.min(@start, chars.size) - 1) do |index|
            if chars[index] == @content
              start_cut = index + 1
            else
              break
            end
          end if @start > 0 && !chars.empty?

          stop_cut = chars.size
          @stop.times do |index|
            reverse_index = chars.size - index - 1
            break if reverse_index < 0

            if chars[reverse_index] == @content
              stop_cut = reverse_index
            else
              break
            end
          end

          chars[start_cut...stop_cut].join
        end
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Strip"
          json.field "content", @content.to_s
          json.field "start", @start
          json.field "stop", @stop
        end
      end

      def self.from_json(json : String) : self
        from_json(JSON.parse(json))
      end

      def self.from_json(data : JSON::Any) : self
        object = data.as_h? || raise(Exception.new("Expected object"))
        type = object["type"]?.try(&.as_s?)
        raise Exception.new("Invalid decoder type") if type && type != "Strip"

        content = object["content"]?.try(&.as_s?) || raise(Exception.new("missing field `content`"))
        new(
          content.each_char.first,
          object["start"]?.try(&.as_i?) || 0,
          object["stop"]?.try(&.as_i?) || 0,
        )
      end
    end
  end
end
