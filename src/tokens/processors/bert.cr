require "json"

module Tokens
  module PostProcessors
    class BertProcessing
      include Tokens::PostProcessor

      getter sep : Tuple(String, UInt32)
      getter cls : Tuple(String, UInt32)

      def initialize(@sep : Tuple(String, UInt32) = {"[SEP]", 102_u32}, @cls : Tuple(String, UInt32) = {"[CLS]", 101_u32})
      end

      def self.default : self
        new
      end

      def get_sep_copy : Tuple(String, UInt32)
        {@sep[0], @sep[1]}
      end

      def get_cls_copy : Tuple(String, UInt32)
        {@cls[0], @cls[1]}
      end

      def added_tokens(is_pair : Bool) : Int32
        is_pair ? 3 : 2
      end

      def process(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding?, add_special_tokens : Bool) : Tokens::Encoding
        unless add_special_tokens
          if pe = pair_encoding
            return merge_encodings(encoding, pe)
          else
            r = Hash(UInt64, ::Range(UInt64, UInt64)).new
            r[0_u64] = 0_u64...encoding.length.to_u64
            return Tokens::Encoding.new(
              ids: encoding.ids,
              type_ids: encoding.type_ids,
              tokens: encoding.tokens,
              words: encoding.words,
              offsets: encoding.offsets,
              special_tokens_mask: encoding.special_tokens_mask,
              attention_mask: encoding.attention_mask,
              overflowing: encoding.overflowing.map(&.copy),
              sequence_ranges: r
            )
          end
        else
          if pe = pair_encoding
            build_pair(encoding, pe)
          else
            build_single(encoding)
          end
        end
      end

      private def build_single(encoding : Tokens::Encoding) : Tokens::Encoding
        overflowings = encoding.overflowing.map(&.copy)

        ids = [@cls[1]] + encoding.ids + [@sep[1]]
        type_ids = [0_u32] + encoding.type_ids + [0_u32]
        tokens = [@cls[0]] + encoding.tokens + [@sep[0]]
        words = [nil] of UInt32? + encoding.words + [nil]
        offsets = [{0_u32, 0_u32}] + encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = [1_u32] + encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)

        wrapped_overflowings = overflowings.map do |o|
          wrap_single_overflowing(o)
        end

        r = Hash(UInt64, ::Range(UInt64, UInt64)).new
        r[0_u64] = 1_u64...(ids.size - 1).to_u64

        Tokens::Encoding.new(
          ids: ids,
          type_ids: type_ids,
          tokens: tokens,
          words: words,
          offsets: offsets,
          special_tokens_mask: special_tokens_mask,
          attention_mask: attention_mask,
          overflowing: wrapped_overflowings,
          sequence_ranges: r
        )
      end

      private def build_pair(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding) : Tokens::Encoding
        main_overflowings = encoding.overflowing.map(&.copy)
        pair_overflowings = pair_encoding.overflowing.map(&.copy)

        first_sep_idx = 1 + encoding.ids.size

        ids = [@cls[1]] + encoding.ids + [@sep[1]] + pair_encoding.ids + [@sep[1]]
        type_ids = [0_u32] + encoding.type_ids + [0_u32] + Array(UInt32).new(pair_encoding.ids.size + 1, 1_u32)
        tokens = [@cls[0]] + encoding.tokens + [@sep[0]] + pair_encoding.tokens + [@sep[0]]
        words = [nil] of UInt32? + encoding.words + [nil] + pair_encoding.words + [nil]
        offsets = [{0_u32, 0_u32}] + encoding.offsets + [{0_u32, 0_u32}] + pair_encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = [1_u32] + encoding.special_tokens_mask + [1_u32] + pair_encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)

        wrapped_overflowings = [] of Tokens::Encoding
        main_overflowings.each do |o|
          wrapped_overflowings << wrap_single_overflowing(o)
        end
        pair_overflowings.each do |o|
          wrapped_overflowings << wrap_pair_overflowing(o)
        end

        sr = Hash(UInt64, ::Range(UInt64, UInt64)).new
        sr[0_u64] = 1_u64...first_sep_idx.to_u64
        sr[1_u64] = (first_sep_idx + 1).to_u64...(ids.size - 1).to_u64

        Tokens::Encoding.new(
          ids: ids,
          type_ids: type_ids,
          tokens: tokens,
          words: words,
          offsets: offsets,
          special_tokens_mask: special_tokens_mask,
          attention_mask: attention_mask,
          overflowing: wrapped_overflowings,
          sequence_ranges: sr
        )
      end

      private def wrap_single_overflowing(encoding : Tokens::Encoding) : Tokens::Encoding
        ids = [@cls[1]] + encoding.ids + [@sep[1]]
        type_ids = [0_u32] + encoding.type_ids + [0_u32]
        tokens = [@cls[0]] + encoding.tokens + [@sep[0]]
        words = [nil] of UInt32? + encoding.words + [nil]
        offsets = [{0_u32, 0_u32}] + encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = [1_u32] + encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)
        r = Hash(UInt64, ::Range(UInt64, UInt64)).new
        r[0_u64] = 1_u64...(ids.size - 1).to_u64

        Tokens::Encoding.new(
          ids: ids,
          type_ids: type_ids,
          tokens: tokens,
          words: words,
          offsets: offsets,
          special_tokens_mask: special_tokens_mask,
          attention_mask: attention_mask,
          overflowing: [] of Tokens::Encoding,
          sequence_ranges: r
        )
      end

      private def wrap_pair_overflowing(encoding : Tokens::Encoding) : Tokens::Encoding
        ids = encoding.ids + [@sep[1]]
        type_ids = encoding.type_ids + [1_u32]
        tokens = encoding.tokens + [@sep[0]]
        words = encoding.words + [nil] of UInt32?
        offsets = encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)
        r = Hash(UInt64, ::Range(UInt64, UInt64)).new
        r[0_u64] = 0_u64...(ids.size - 1).to_u64

        Tokens::Encoding.new(
          ids: ids,
          type_ids: type_ids,
          tokens: tokens,
          words: words,
          offsets: offsets,
          special_tokens_mask: special_tokens_mask,
          attention_mask: attention_mask,
          overflowing: [] of Tokens::Encoding,
          sequence_ranges: r
        )
      end

      private def merge_encodings(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding) : Tokens::Encoding
        e1 = encoding.copy
        e2 = pair_encoding.copy
        e1_len = e1.length
        e1.set_sequence_id(0_u64)
        e1.set_type_ids(Array(UInt32).new(e1.length, 0_u32))
        e2.set_sequence_id(1_u64)
        e2.set_type_ids(Array(UInt32).new(e2.length, 1_u32))
        e1.merge_with(e2, false)
        e1
      end

      def ==(other : self) : Bool
        @sep == other.sep && @cls == other.cls
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "BertProcessing"
          json.field "sep" do
            json.array do
              json.string @sep[0]
              json.number @sep[1]
            end
          end
          json.field "cls" do
            json.array do
              json.string @cls[0]
              json.number @cls[1]
            end
          end
        end
      end

      def self.from_json(json : String, check_type : Bool = true) : self
        data = JSON.parse(json)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?

        obj = data.as_h

        if check_type
          type = obj["type"]?.try(&.as_s?)
          raise JSON::ParseException.new("Expected type BertProcessing, got #{type}", 0, 0) if type.nil? || type != "BertProcessing"
        end

        sep_arr = obj["sep"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing sep", 0, 0))
        cls_arr = obj["cls"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing cls", 0, 0))

        sep_val = sep_arr[0].as_s
        sep_id = sep_arr[1].as_i.to_u32
        cls_val = cls_arr[0].as_s
        cls_id = cls_arr[1].as_i.to_u32

        new({sep_val, sep_id}, {cls_val, cls_id})
      end
    end
  end
end
