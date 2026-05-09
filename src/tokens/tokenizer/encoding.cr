require "json"

module Tokens
  struct Encoding
    include JSON::Serializable

    getter ids : Array(UInt32)
    getter type_ids : Array(UInt32)
    getter tokens : Array(String)
    getter words : Array(UInt32?)
    getter offsets : Array(Tuple(UInt32, UInt32))
    getter special_tokens_mask : Array(UInt32)
    getter attention_mask : Array(UInt32)
    getter overflowing : Array(Encoding)
    getter sequence_ranges : Hash(UInt64, ::Range(UInt64, UInt64))

    def initialize(
      @ids = [] of UInt32,
      @type_ids = [] of UInt32,
      @tokens = [] of String,
      words : Array = [] of UInt32?,
      @offsets = [] of Tuple(UInt32, UInt32),
      @special_tokens_mask = [] of UInt32,
      @attention_mask = [] of UInt32,
      @overflowing = [] of Encoding,
      @sequence_ranges = {} of UInt64 => ::Range(UInt64, UInt64),
    )
      @words = words.map { |w| w.as(UInt32?) }
    end

    def self.with_capacity(len : Int32)
      new(
        ids: Array(UInt32).new(len),
        type_ids: Array(UInt32).new(len),
        tokens: Array(String).new(len),
        words: Array(UInt32?).new(len),
        offsets: Array(Tuple(UInt32, UInt32)).new(len),
        special_tokens_mask: Array(UInt32).new(len),
        attention_mask: Array(UInt32).new(len)
      )
    end

    def self.from_tokens(tokens : Array(Token), type_id : UInt32)
      ids = tokens.map(&.id)
      tok_strings = tokens.map(&.value)
      offsets = tokens.map(&.offsets)
      length = tokens.size
      new(
        ids: ids,
        tokens: tok_strings,
        offsets: offsets,
        words: Array(UInt32?).new(length, nil),
        type_ids: Array(UInt32).new(length, type_id),
        attention_mask: Array(UInt32).new(length, 1_u32),
        special_tokens_mask: Array(UInt32).new(length, 0_u32)
      )
    end

    def empty? : Bool
      @ids.empty?
    end

    def length : Int32
      @ids.size
    end

    def n_sequences : Int32
      @sequence_ranges.empty? ? 1 : @sequence_ranges.size
    end

    def set_sequence_id(sequence_id : UInt64)
      len = length
      @sequence_ranges[sequence_id] = 0_u64...len.to_u64
    end

    def get_sequence_ids : Array(UInt64?)
      seqs = Array(UInt64?).new(length, nil)
      n_sequences.times do |seq_id|
        range = sequence_range(seq_id)
        range.each do |i|
          seqs[i] = seq_id.to_u64
        end
      end
      seqs
    end

    def set_type_ids(type_ids : Array(UInt32))
      @type_ids = type_ids
    end

    def take_overflowing : Array(Encoding)
      prev = @overflowing
      @overflowing = [] of Encoding
      prev
    end

    def process_tokens_with_offsets_mut(&block : Int32, String, Tuple(UInt32, UInt32) -> Tuple(UInt32, UInt32))
      @tokens.each_with_index do |token, i|
        @offsets[i] = yield i, token, @offsets[i]
      end
    end

    private def sequence_range(sequence_id : Int32) : ::Range(UInt64, UInt64)
      @sequence_ranges.fetch(sequence_id.to_u64, 0_u64...length.to_u64)
    end

    def token_to_sequence(token : Int32) : UInt64?
      return nil if token >= length
      return 0_u64 if @sequence_ranges.empty?
      @sequence_ranges.each do |seq_id, range|
        return seq_id if range.includes?(token)
      end
      nil
    end

    def word_to_tokens(word : UInt32, sequence_id : Int32) : Tuple(Int32, Int32)?
      start = nil
      stop = nil
      seq_range = sequence_range(sequence_id)
      return nil if seq_range.begin >= @words.size

      slice = @words[seq_range.begin.to_i32..(seq_range.end - 1).clamp(0, @words.size - 1).to_i32]
      slice.each_with_index do |w, i|
        next unless w == word
        start = i if start.nil? || i < start
        stop = i + 1 if stop.nil? || i >= stop
      end

      if s = start
        if e = stop
          return {seq_range.begin.to_i32 + s, seq_range.begin.to_i32 + e}
        end
      end
      nil
    end

    def word_to_chars(word : UInt32, sequence_id : Int32) : Tuple(UInt32, UInt32)?
      wt = word_to_tokens(word, sequence_id)
      return nil unless wt
      start, stop = wt
      return nil if stop == 0
      {(@offsets[start][0]), (@offsets[stop - 1][1])}
    end

    def token_to_chars(token : Int32) : Tuple(UInt64, Tuple(UInt32, UInt32))?
      seq = token_to_sequence(token)
      return nil unless seq
      off = @offsets[token]?
      return nil unless off
      {seq, off}
    end

    def token_to_word(token : Int32) : Tuple(UInt64, UInt32)?
      seq = token_to_sequence(token)
      return nil unless seq
      w = @words[token]?
      return nil unless w
      {seq, w}
    end

    def char_to_token(pos : UInt32, sequence_id : Int32) : Int32?
      seq_range = sequence_range(sequence_id)
      return nil if seq_range.begin >= @offsets.size

      slice = @offsets[seq_range.begin.to_i32..(seq_range.end - 1).clamp(0, @offsets.size - 1).to_i32]
      idx = slice.index { |(s, e)| pos >= s && pos < e }
      idx.try { |i| (seq_range.begin + i).to_i32 }
    end

    def char_to_word(pos : UInt32, sequence_id : Int32) : UInt32?
      ct = char_to_token(pos, sequence_id)
      return nil unless ct
      tw = token_to_word(ct)
      return nil unless tw
      tw[1]
    end

    def truncate(max_len : Int32, stride : Int32, direction : TruncationDirection)
      encoding_len = @ids.size
      return if encoding_len == 0

      if max_len == 0
        o = Encoding.new(ids: @ids, tokens: @tokens, type_ids: @type_ids, words: @words, offsets: @offsets, special_tokens_mask: @special_tokens_mask, attention_mask: @attention_mask, overflowing: @overflowing, sequence_ranges: @sequence_ranges)
        initialize
        @overflowing << o
        return
      end

      return if max_len >= encoding_len

      raise "stride must be strictly less than max_len" unless stride < max_len

      @sequence_ranges.clear
      offset_v = max_len - stride
      end_flag = false

      parts_ranges = case direction
                     when TruncationDirection::Right
                       (0...encoding_len).step(offset_v).compact_map { |s|
                         next nil if end_flag
                         stop = Math.min(s + max_len, encoding_len)
                         end_flag = stop == encoding_len
                         {s, stop}
                       }.to_a
                     when TruncationDirection::Left
                       (0...encoding_len).to_a.reverse.each.step(offset_v).compact_map { |stop|
                         stop = stop + 1
                         start = {stop - max_len, 0}.max
                         next nil if start >= stop || end_flag
                         end_flag = start == 0
                         {start, stop}
                       }.to_a
                     else
                       [] of Tuple(Int32, Int32)
                     end

      return if parts_ranges.empty?

      start, stop = parts_ranges[0]
      new_encoding = Encoding.new(
        ids: @ids[start...stop],
        type_ids: @type_ids[start...stop],
        tokens: @tokens[start...stop],
        words: @words[start...stop],
        offsets: @offsets[start...stop],
        special_tokens_mask: @special_tokens_mask[start...stop],
        attention_mask: @attention_mask[start...stop]
      )

      (1...parts_ranges.size).each do |i|
        s, p_stop = parts_ranges[i]
        new_encoding.overflowing << Encoding.new(
          ids: @ids[s...p_stop],
          type_ids: @type_ids[s...p_stop],
          tokens: @tokens[s...p_stop],
          words: @words[s...p_stop],
          offsets: @offsets[s...p_stop],
          special_tokens_mask: @special_tokens_mask[s...p_stop],
          attention_mask: @attention_mask[s...p_stop]
        )
      end

      @ids = new_encoding.ids
      @type_ids = new_encoding.type_ids
      @tokens = new_encoding.tokens
      @words = new_encoding.words
      @offsets = new_encoding.offsets
      @special_tokens_mask = new_encoding.special_tokens_mask
      @attention_mask = new_encoding.attention_mask
      @overflowing = new_encoding.overflowing
      @sequence_ranges = {} of UInt64 => ::Range(UInt64, UInt64)
    end

    def copy : Encoding
      Encoding.new(
        ids: @ids.dup,
        type_ids: @type_ids.dup,
        tokens: @tokens.dup,
        words: @words.dup,
        offsets: @offsets.dup,
        special_tokens_mask: @special_tokens_mask.dup,
        attention_mask: @attention_mask.dup,
        overflowing: @overflowing.map(&.copy),
        sequence_ranges: @sequence_ranges.transform_values { |range|
          if range.exclusive?
            range.begin...range.end
          else
            range.begin..range.end
          end
        }
      )
    end

    def merge_with(pair : Encoding, growing_offsets : Bool)
      overflowings = [] of Encoding

      @overflowing.each do |self_o|
        n_encoding = self_o.copy
        n_encoding.merge_with(pair.copy, growing_offsets)
        overflowings << n_encoding

        pair.overflowing.each do |other_o|
          n_encoding = self_o.copy
          n_encoding.merge_with(other_o.copy, growing_offsets)
          overflowings << n_encoding
        end
      end

      pair.overflowing.each do |other_o|
        n_encoding = self.copy
        n_encoding.merge_with(other_o.copy, growing_offsets)
        overflowings << n_encoding
      end

      original_self_len = length

      pair.sequence_ranges.each do |seq_id, range|
        new_begin = (original_self_len + range.begin).to_u64
        new_end = (original_self_len + range.end).to_u64
        @sequence_ranges[seq_id] = if range.exclusive?
                                     new_begin...new_end
                                   else
                                     new_begin..new_end
                                   end
      end

      @ids.concat(pair.ids)
      @type_ids.concat(pair.type_ids)
      @tokens.concat(pair.tokens)
      @words.concat(pair.words)

      starting_offset = growing_offsets ? (@offsets.last? || {0_u32, 0_u32})[1] : 0_u32
      @offsets.concat(pair.offsets.map { |(s, e)| {s + starting_offset, e + starting_offset} })
      @special_tokens_mask.concat(pair.special_tokens_mask)
      @attention_mask.concat(pair.attention_mask)
      @overflowing = overflowings
    end

    def self.merge(encodings : Array(Encoding), growing_offsets : Bool) : Encoding
      encoding = Encoding.new
      encodings.each do |sub|
        encoding.merge_with(sub, growing_offsets)
      end
      encoding
    end

    def pad(target_length : Int32, pad_id : UInt32, pad_type_id : UInt32, pad_token : String, direction : PaddingDirection)
      @overflowing.each do |encoding|
        encoding.pad(target_length, pad_id, pad_type_id, pad_token, direction)
      end

      return if @ids.size >= target_length

      pad_length = target_length - @ids.size

      case direction
      when PaddingDirection::Left
        pad_ids = Array(UInt32).new(pad_length, pad_id)
        pad_type_ids = Array(UInt32).new(pad_length, pad_type_id)
        pad_tokens = Array(String).new(pad_length, pad_token)
        pad_words = Array(UInt32?).new(pad_length, nil)
        pad_attention = Array(UInt32).new(pad_length, 0_u32)
        pad_special = Array(UInt32).new(pad_length, 1_u32)
        pad_offsets = Array(Tuple(UInt32, UInt32)).new(pad_length, {0_u32, 0_u32})

        @ids = pad_ids + @ids
        @type_ids = pad_type_ids + @type_ids
        @tokens = pad_tokens + @tokens
        @words = pad_words + @words
        @attention_mask = pad_attention + @attention_mask
        @special_tokens_mask = pad_special + @special_tokens_mask
        @offsets = pad_offsets + @offsets

        @sequence_ranges.each do |seq_id, range|
          new_begin = range.begin + pad_length
          new_end = range.end + pad_length
          @sequence_ranges[seq_id] = if range.exclusive?
                                       new_begin...new_end
                                     else
                                       new_begin..new_end - 1
                                     end
        end
      when PaddingDirection::Right
        pad_length.times { @ids << pad_id }
        pad_length.times { @type_ids << pad_type_id }
        pad_length.times { @tokens << pad_token }
        pad_length.times { @words << nil }
        pad_length.times { @attention_mask << 0_u32 }
        pad_length.times { @special_tokens_mask << 1_u32 }
        pad_length.times { @offsets << {0_u32, 0_u32} }
      end
    end
  end

  enum TruncationDirection
    Left
    Right
  end

  enum PaddingDirection
    Left
    Right
  end

  struct TruncationParams
    include JSON::Serializable

    @max_length : UInt64 = 512_u64
    @strategy : TruncationStrategy = TruncationStrategy::LongestFirst
    @stride : UInt64 = 0_u64
    @direction : TruncationDirection = TruncationDirection::Right

    getter max_length : UInt64
    getter strategy : TruncationStrategy
    getter stride : UInt64
    getter direction : TruncationDirection

    def initialize(@max_length = 512_u64, @strategy = TruncationStrategy::LongestFirst, @stride = 0_u64, @direction = TruncationDirection::Right)
    end
  end

  enum TruncationStrategy
    LongestFirst
    OnlyFirst
    OnlySecond
  end

  struct PaddingParams
    include JSON::Serializable

    getter strategy : PaddingStrategy
    getter direction : PaddingDirection
    getter pad_to_multiple_of : UInt64?
    getter pad_id : UInt32
    getter pad_type_id : UInt32
    getter pad_token : String
    getter fixed_size : UInt64?

    def initialize(@strategy = PaddingStrategy::BatchLongest, @direction = PaddingDirection::Right, @pad_to_multiple_of = nil, @pad_id = 0_u32, @pad_type_id = 0_u32, @pad_token = "[PAD]", @fixed_size = nil)
    end
  end

  enum PaddingStrategy
    BatchLongest
    Fixed
  end

  def self.pad_encodings(encodings : Array(Encoding), params : PaddingParams)
    return if encodings.empty?

    pad_length = 0_u64
    case params.strategy
    when PaddingStrategy::Fixed
      pad_length = params.fixed_size || 0_u64
    when PaddingStrategy::BatchLongest
      pad_length = encodings.max_of(&.length).to_u64
    end

    if multiple = params.pad_to_multiple_of
      pad_multiple = multiple.as(UInt64)
      if pad_multiple > 0 && pad_length % pad_multiple > 0
        pad_length += pad_multiple - pad_length % pad_multiple
      end
    end

    encodings.each do |encoding|
      encoding.pad(pad_length.to_i32, params.pad_id, params.pad_type_id, params.pad_token, params.direction)
    end
  end
end
