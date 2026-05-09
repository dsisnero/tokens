require "json"

module Tokens
  module PostProcessors
    class RobertaProcessing
      include Tokens::PostProcessor

      getter sep : Tuple(String, UInt32)
      getter cls : Tuple(String, UInt32)
      getter? trim_offsets : Bool
      getter? add_prefix_space : Bool

      def initialize(
        @sep : Tuple(String, UInt32) = {"</s>", 2_u32},
        @cls : Tuple(String, UInt32) = {"<s>", 0_u32},
        @trim_offsets = true,
        @add_prefix_space = true,
      )
      end

      def self.default : self
        new
      end

      def trim_offsets(v : Bool) : self
        self.class.new(@sep, @cls, v, @add_prefix_space)
      end

      def add_prefix_space(v : Bool) : self
        self.class.new(@sep, @cls, @trim_offsets, v)
      end

      def get_sep_copy : Tuple(String, UInt32)
        {@sep[0], @sep[1]}
      end

      def get_cls_copy : Tuple(String, UInt32)
        {@cls[0], @cls[1]}
      end

      def added_tokens(is_pair : Bool) : Int32
        is_pair ? 4 : 2
      end

      def process(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding?, add_special_tokens : Bool) : Tokens::Encoding
        e1 = encoding.copy
        e2 = pair_encoding.try(&.copy)

        if @trim_offsets
          Tokens::PreTokenizers.process_offsets(e1, @add_prefix_space)
          e1.overflowing.each { |o| Tokens::PreTokenizers.process_offsets(o, @add_prefix_space) }
          if e2
            Tokens::PreTokenizers.process_offsets(e2, @add_prefix_space)
            e2.overflowing.each { |o| Tokens::PreTokenizers.process_offsets(o, @add_prefix_space) }
          end
        end

        # Roberta sets all type_ids to 0
        e1.set_type_ids(Array(UInt32).new(e1.length, 0_u32))
        e2.try { |e| e.set_type_ids(Array(UInt32).new(e.length, 0_u32)) }

        unless add_special_tokens
          if e2
            return merge_encodings(e1, e2)
          else
            r = Hash(UInt64, ::Range(UInt64, UInt64)).new
            r[0_u64] = 0_u64...e1.length.to_u64
            return Tokens::Encoding.new(
              ids: e1.ids,
              type_ids: e1.type_ids,
              tokens: e1.tokens,
              words: e1.words,
              offsets: e1.offsets,
              special_tokens_mask: e1.special_tokens_mask,
              attention_mask: e1.attention_mask,
              overflowing: e1.overflowing,
              sequence_ranges: r
            )
          end
        end

        if e2
          build_pair(e1, e2)
        else
          build_single(e1)
        end
      end

      private def build_single(encoding : Tokens::Encoding) : Tokens::Encoding
        overflowings = encoding.take_overflowing

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
        main_overflowings = encoding.take_overflowing
        pair_overflowings = pair_encoding.take_overflowing

        first_sep_idx = 1 + encoding.ids.size

        ids = [@cls[1]] + encoding.ids + [@sep[1]] + [@sep[1]] + pair_encoding.ids + [@sep[1]]
        type_ids = Array(UInt32).new(ids.size, 0_u32)
        tokens = [@cls[0]] + encoding.tokens + [@sep[0]] + [@sep[0]] + pair_encoding.tokens + [@sep[0]]
        words = [nil] of UInt32? + encoding.words + [nil] + [nil] + pair_encoding.words + [nil]
        offsets = [{0_u32, 0_u32}] + encoding.offsets + [{0_u32, 0_u32}] + [{0_u32, 0_u32}] + pair_encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = [1_u32] + encoding.special_tokens_mask + [1_u32] + [1_u32] + pair_encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)

        wrapped_overflowings = [] of Tokens::Encoding
        main_overflowings.each do |o|
          wrapped_overflowings << wrap_single_overflowing(o)
        end
        pair_overflowings.each do |o|
          wrapped_overflowings << wrap_pair_overflowing(o)
        end

        # pair region: [SEP] pair_ids [SEP]
        # pair_region_start = first_sep_idx + 1
        # seq 1 starts after the leading SEP of the pair region
        sr = Hash(UInt64, ::Range(UInt64, UInt64)).new
        sr[0_u64] = 1_u64...first_sep_idx.to_u64
        sr[1_u64] = (first_sep_idx + 2).to_u64...(ids.size - 1).to_u64

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
        type_ids = Array(UInt32).new(ids.size, 0_u32)
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
        ids = [@sep[1]] + encoding.ids + [@sep[1]]
        type_ids = Array(UInt32).new(ids.size, 0_u32)
        tokens = [@sep[0]] + encoding.tokens + [@sep[0]]
        words = [nil] of UInt32? + encoding.words + [nil]
        offsets = [{0_u32, 0_u32}] + encoding.offsets + [{0_u32, 0_u32}]
        special_tokens_mask = [1_u32] + encoding.special_tokens_mask + [1_u32]
        attention_mask = Array(UInt32).new(ids.size, 1_u32)
        r = Hash(UInt64, ::Range(UInt64, UInt64)).new
        r[1_u64] = 1_u64...(ids.size - 1).to_u64

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
        e1 = encoding
        e2 = pair_encoding
        e1.set_sequence_id(0_u64)
        e2.set_sequence_id(1_u64)
        e1.merge_with(e2, false)
        e1
      end

      def ==(other : self) : Bool
        @sep == other.sep &&
          @cls == other.cls &&
          @trim_offsets == other.trim_offsets? &&
          @add_prefix_space == other.add_prefix_space?
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "RobertaProcessing"
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
          json.field "trim_offsets", @trim_offsets
          json.field "add_prefix_space", @add_prefix_space
        end
      end

      def self.from_json(json : String, check_type : Bool = true) : self
        data = JSON.parse(json)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?

        obj = data.as_h

        if check_type
          type = obj["type"]?.try(&.as_s?)
          raise JSON::ParseException.new("Expected type RobertaProcessing, got #{type}", 0, 0) if type.nil? || type != "RobertaProcessing"
        end

        sep_arr = obj["sep"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing sep", 0, 0))
        cls_arr = obj["cls"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing cls", 0, 0))
        trim_offsets_json = obj["trim_offsets"]?
        add_prefix_space_json = obj["add_prefix_space"]?

        # All fields required for untagged matching (upstream behavior)
        if check_type
          trim_offsets = trim_offsets_json.try(&.as_bool) || true
          add_prefix_space = add_prefix_space_json.try(&.as_bool) || true
        else
          raise JSON::ParseException.new("Missing trim_offsets", 0, 0) unless trim_offsets_json
          raise JSON::ParseException.new("Missing add_prefix_space", 0, 0) unless add_prefix_space_json
          trim_offsets = trim_offsets_json.as_bool
          add_prefix_space = add_prefix_space_json.as_bool
        end

        sep_val = sep_arr[0].as_s
        sep_id = sep_arr[1].as_i.to_u32
        cls_val = cls_arr[0].as_s
        cls_id = cls_arr[1].as_i.to_u32

        new({sep_val, sep_id}, {cls_val, cls_id}, trim_offsets, add_prefix_space)
      end
    end
  end
end
