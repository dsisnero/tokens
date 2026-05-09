require "unicode"

module Tokens
  enum OffsetReferential
    Original
    Normalized
  end

  enum SplitDelimiterBehavior
    Removed
    Isolated
    MergedWithPrevious
    MergedWithNext
    Contiguous
  end

  enum OffsetType
    Byte
    Char
    None
  end

  module Range
    module Base
      abstract def into_full_range(max_len : Int32) : ::Range(Int32, Int32)
      abstract def len : Int32?
    end

    struct Original(B, E)
      include Base

      getter range : ::Range(B, E)

      def initialize(@range : ::Range(B, E))
      end

      def into_full_range(max_len : Int32) : ::Range(Int32, Int32)
        range_to_full(@range, max_len)
      end

      def len : Int32?
        range_len(@range)
      end

      private def range_to_full(range, max_len : Int32) : ::Range(Int32, Int32)
        start = range.begin.nil? ? 0 : range.begin.not_nil!.to_i32
        finish = if range.end.nil?
                   max_len
                 else
                   stop = range.end.not_nil!.to_i32
                   range.excludes_end? ? stop : stop + 1
                 end
        start...finish
      end

      private def range_len(range) : Int32?
        return nil if range.end.nil?

        finish = range.end.not_nil!.to_i32
        finish += 1 unless range.excludes_end?
        start = range.begin.nil? ? 0 : range.begin.not_nil!.to_i32
        finish - start
      end
    end

    struct Normalized(B, E)
      include Base

      getter range : ::Range(B, E)

      def initialize(@range : ::Range(B, E))
      end

      def into_full_range(max_len : Int32) : ::Range(Int32, Int32)
        range_to_full(@range, max_len)
      end

      def len : Int32?
        range_len(@range)
      end

      private def range_to_full(range, max_len : Int32) : ::Range(Int32, Int32)
        start = range.begin.nil? ? 0 : range.begin.not_nil!.to_i32
        finish = if range.end.nil?
                   max_len
                 else
                   stop = range.end.not_nil!.to_i32
                   range.excludes_end? ? stop : stop + 1
                 end
        start...finish
      end

      private def range_len(range) : Int32?
        return nil if range.end.nil?

        finish = range.end.not_nil!.to_i32
        finish += 1 unless range.excludes_end?
        start = range.begin.nil? ? 0 : range.begin.not_nil!.to_i32
        finish - start
      end
    end
  end

  class NormalizedString
    getter original : String
    getter normalized : String
    getter alignments : Array(Tuple(UInt32, UInt32))
    getter original_shift : UInt32

    def initialize(
      @original = "",
      @normalized = "",
      @alignments = [] of Tuple(UInt32, UInt32),
      @original_shift = 0_u32,
    )
    end

    def ==(other : self) : Bool
      @original == other.original &&
        @normalized == other.normalized &&
        @alignments == other.alignments &&
        @original_shift == other.original_shift
    end

    def clone : self
      self.class.new(
        original: @original.dup,
        normalized: @normalized.dup,
        alignments: @alignments.map { |(start, finish)| {start, finish} },
        original_shift: @original_shift
      )
    end

    def self.new(s : String)
      from(s)
    end

    def self.new(
      s : String,
      original : String,
      normalized : String,
      alignments : Array(Tuple(UInt32, UInt32)),
      original_shift : UInt32,
    )
      new(original: original, normalized: normalized, alignments: alignments, original_shift: original_shift)
    end

    def self.from(s : String)
      alignments = [] of Tuple(UInt32, UInt32)
      NormalizedString.byte_char_entries(s).each do |byte_offset, char|
        stop = byte_offset + char.bytesize
        char.bytesize.times do
          alignments << {byte_offset.to_u32, stop.to_u32}
        end
      end
      new(original: s.dup, normalized: s.dup, alignments: alignments)
    end

    def get : String
      @normalized
    end

    def get_original : String
      @original
    end

    def offsets_original : Tuple(UInt32, UInt32)
      {@original_shift, @original_shift + len_original.to_u32}
    end

    def length : Int32
      @normalized.bytesize
    end

    def len_original : Int32
      @original.bytesize
    end

    def empty? : Bool
      @normalized.empty?
    end

    def get_range(range) : String?
      case range
      when Range::Original
        converted = convert_offsets(range)
        return nil unless converted
        byte_slice(@normalized, converted)
      when Range::Normalized
        normalized_range = validate_range(range)
        return nil unless normalized_range
        byte_slice(@normalized, normalized_range.as(Range::Normalized).into_full_range(length))
      end
    end

    def get_range_original(range) : String?
      case range
      when Range::Original
        original_range = validate_range(range)
        return nil unless original_range
        byte_slice(@original, original_range.as(Range::Original).into_full_range(len_original))
      when Range::Normalized
        converted = convert_offsets(range)
        return nil unless converted
        byte_slice(@original, converted)
      end
    end

    def slice(range) : NormalizedString?
      validated = validate_range(range)
      return nil unless validated

      normalized_range = 0...0
      original_range = 0...0
      case validated
      when Range::Original
        nr = convert_offsets(validated)
        return nil unless nr
        normalized_range = nr
        original_range = validated.into_full_range(len_original)
      when Range::Normalized
        orr = convert_offsets(validated)
        return nil unless orr
        normalized_range = validated.into_full_range(length)
        original_range = orr
      else
        return nil
      end

      normalized_text = byte_slice(@normalized, normalized_range) || ""
      original_text = byte_slice(@original, original_range) || ""
      shift = original_range.begin.to_u32

      NormalizedString.new(
        original: original_text,
        normalized: normalized_text,
        alignments: @alignments[normalized_range].map { |(start, finish)| {start - shift, finish - shift} },
        original_shift: @original_shift + shift
      )
    end

    def convert_offsets(range) : ::Range(Int32, Int32)?
      target = 0...0
      original = false
      case range
      when Range::Original
        validated = validate_range(range)
        return nil unless validated
        target = validated.as(Range::Original).into_full_range(len_original)
        original = true
      when Range::Normalized
        validated = validate_range(range)
        return nil unless validated
        target = validated.as(Range::Normalized).into_full_range(length)
        original = false
      else
        return nil
      end

      return target if target.begin == target.end
      return nil if target.begin > target.end

      if original && @original.empty? && target.begin == 0 && target.end == 0
        return 0...length
      end
      if !original && @normalized.empty? && target.begin == 0 && target.end == 0
        return 0...len_original
      end

      if original
        start_idx = nil
        end_idx = nil

        @alignments.each_with_index do |(align_start, align_end), index|
          if start_idx.nil? && target.begin <= align_start.to_i32 && align_start != align_end
            start_idx = index
          end
          end_idx = index + 1 if target.end >= align_end.to_i32
        end

        case {start_idx, end_idx}
        when {Int32, Nil}
          start_idx...start_idx
        when {Nil, Int32}
          end_idx...end_idx
        when {Int32, Int32}
          start_idx...end_idx
        else
          nil
        end
      else
        align_slice = @alignments[target]?
        return nil if align_slice.nil? || align_slice.empty?

        start = align_slice[0][0].to_i32
        finish = align_slice[-1][1].to_i32
        start...finish
      end
    end

    def transform(dest, initial_offset : Int32)
      transform_range(Range::Original.new(0...len_original), dest, initial_offset)
      self
    end

    def transform_range(range, dest, initial_offset : Int32)
      validated = validate_range(range)
      return self unless validated

      normalized_range = 0...0
      original_range = 0...0
      case validated
      when Range::Original
        nr = convert_offsets(validated)
        return self unless nr
        normalized_range = nr
        original_range = validated.into_full_range(len_original)
      when Range::Normalized
        orr = convert_offsets(validated)
        return self unless orr
        normalized_range = validated.into_full_range(length)
        original_range = orr
      else
        return self
      end

      replaced = byte_slice(@normalized, normalized_range) || ""
      replaced_chars = replaced.chars
      replaced_index = 0
      offset = initial_offset + normalized_range.begin

      replacement_alignments = [] of Tuple(UInt32, UInt32)
      replacement_text = String.build do |io|
        dest.each do |item|
          char = item[0].as(Char)
          change = item[1].to_i

          alignment = if change > 0
                        if offset < 1
                          {0_u32, 0_u32}
                        else
                          @alignments[offset - 1]? || {0_u32, 0_u32}
                        end
                      else
                        @alignments[offset]? || {0_u32, 0_u32}
                      end

          replaced_char_size = 0
          if change <= 0
            if existing = replaced_chars[replaced_index]?
              replaced_index += 1
              replaced_char_size = existing.bytesize
            end
          end

          removed_bytes = 0
          if change < 0
            (-change).times do
              if removed = replaced_chars[replaced_index]?
                replaced_index += 1
                removed_bytes += removed.bytesize
              end
            end
          end

          offset += replaced_char_size + removed_bytes
          char.bytesize.times { replacement_alignments << alignment }
          io << char
        end
      end

      prefix = byte_slice(@normalized, 0...normalized_range.begin) || ""
      suffix = byte_slice(@normalized, normalized_range.end...length) || ""
      @normalized = prefix + replacement_text + suffix

      new_alignments = [] of Tuple(UInt32, UInt32)
      new_alignments.concat(@alignments[0...normalized_range.begin])
      new_alignments.concat(replacement_alignments)
      new_alignments.concat(@alignments[normalized_range.end...@alignments.size])
      @alignments = new_alignments

      self
    end

    def nfd
      chars = normalized_chars_for_form(:nfd)
      transform(chars, 0)
      self
    end

    def nfkd
      chars = normalized_chars_for_form(:nfkd)
      transform(chars, 0)
      self
    end

    def nfc
      chars = normalized_chars_for_form(:nfc)
      transform(chars, 0)
      self
    end

    def nfkc
      chars = normalized_chars_for_form(:nfkc)
      transform(chars, 0)
      self
    end

    def map(&block : Char -> Char)
      transformations = @normalized.each_char.map { |char| {block.call(char), 0} }.to_a
      transform(transformations, 0)
      self
    end

    def lowercase
      transformations = [] of Tuple(Char, Int32)
      @normalized.each_char do |char|
        char.to_s.downcase.each_char_with_index do |lowered, index|
          transformations << {lowered, index == 0 ? 0 : 1}
        end
      end
      transform(transformations, 0)
      self
    end

    def uppercase
      transformations = [] of Tuple(Char, Int32)
      @normalized.each_char do |char|
        char.to_s.upcase.each_char_with_index do |uppered, index|
          transformations << {uppered, index == 0 ? 0 : 1}
        end
      end
      transform(transformations, 0)
      self
    end

    def filter(&block : Char -> Bool)
      removed = 0
      removed_start = 0
      transformations = [] of Tuple(Char, Int32)
      last_char = nil

      @normalized.each_char do |char|
        if block.call(char)
          if previous = last_char
            transformations << {previous, -removed}
          else
            removed_start = removed
          end
          last_char = char
          removed = 0
        else
          removed += 1
        end
      end

      transformations << {last_char.not_nil!, -removed} if last_char
      transform(transformations, removed_start)
      self
    end

    def clear : Int32
      len = length
      @normalized = ""
      @alignments = [] of Tuple(UInt32, UInt32)
      len
    end

    def prepend(s : String)
      if next_char = @normalized.each_char.first?
        transformations = [] of Tuple(Char, Int32)
        s.each_char_with_index do |char, index|
          transformations << {char, index == 0 ? 0 : 1}
        end
        transformations << {next_char, 1}
        transform_range(Range::Normalized.new(0...next_char.bytesize), transformations, 0)
      elsif !s.empty?
        transformations = s.each_char.map { |char| {char, 1} }.to_a
        transform_range(Range::Normalized.new(0...0), transformations, 0)
      end
      self
    end

    def append(s : String)
      if last = NormalizedString.byte_char_entries(@normalized).last?
        byte_offset = last[0]
        previous = last[1]
        transformations = [{previous, 0}] + s.each_char.map { |char| {char, 1} }.to_a
        transform_range(Range::Normalized.new(byte_offset...length), transformations, 0)
      elsif !s.empty?
        transformations = s.each_char.map { |char| {char, 1} }.to_a
        transform_range(Range::Normalized.new(0...0), transformations, 0)
      end
      self
    end

    def replace(pattern, content : String)
      matches = pattern.find_matches(@normalized)
      matches.reverse_each do |(offsets, is_match)|
        next unless is_match

        start = offsets[0].to_i32
        finish = offsets[1].to_i32
        removed_chars = (byte_slice(@normalized, start...finish) || "").chars.size

        transformations =
          if content.empty?
            [] of Tuple(Char, Int32)
          else
            items = [] of Tuple(Char, Int32)
            content.each_char_with_index do |char, index|
              if removed_chars > 0
                items << {char, index == 0 ? -(removed_chars - 1) : 1}
              else
                items << {char, 1}
              end
            end
            items
          end

        transform_range(Range::Normalized.new(start...finish), transformations, 0)
      end
      self
    end

    def split(pattern, behavior : SplitDelimiterBehavior) : Array(NormalizedString)
      matches = pattern.find_matches(@normalized)

      splits = [] of Tuple(Tuple(UInt32, UInt32), Bool)
      case behavior
      when SplitDelimiterBehavior::Isolated
        splits = matches.map { |(offsets, _)| {offsets, false} }
      when SplitDelimiterBehavior::Removed
        splits = matches
      when SplitDelimiterBehavior::Contiguous
        previous_match = false
        splits = matches.reduce([] of Tuple(Tuple(UInt32, UInt32), Bool)) do |acc, (offsets, is_match)|
          if is_match == previous_match
            if last = acc.last?
              acc[-1] = { {last[0][0], offsets[1]}, false }
            else
              acc << {offsets, false}
            end
          else
            acc << {offsets, false}
          end
          previous_match = is_match
          acc
        end
      when SplitDelimiterBehavior::MergedWithPrevious
        previous_match = false
        splits = matches.reduce([] of Tuple(Tuple(UInt32, UInt32), Bool)) do |acc, (offsets, is_match)|
          if is_match && !previous_match
            if last = acc.last?
              acc[-1] = { {last[0][0], offsets[1]}, false }
            else
              acc << {offsets, false}
            end
          else
            acc << {offsets, false}
          end
          previous_match = is_match
          acc
        end
      when SplitDelimiterBehavior::MergedWithNext
        previous_match = false
        reversed = matches.reverse.reduce([] of Tuple(Tuple(UInt32, UInt32), Bool)) do |acc, (offsets, is_match)|
          if is_match && !previous_match
            if last = acc.last?
              acc[-1] = { {offsets[0], last[0][1]}, false }
            else
              acc << {offsets, false}
            end
          else
            acc << {offsets, false}
          end
          previous_match = is_match
          acc
        end
        splits = reversed.reverse
      end

      splits.compact_map do |(offsets, remove)|
        next if remove
        slice(Range::Normalized.new(offsets[0]...offsets[1]))
      end
    end

    def lstrip
      lrstrip(true, false)
    end

    def rstrip
      lrstrip(false, true)
    end

    def strip
      lrstrip(true, true)
    end

    def alignments_original : Array(Tuple(UInt32, UInt32))
      return [] of Tuple(UInt32, UInt32) if @alignments.empty?

      original_alignments = [] of Tuple(UInt32, UInt32)
      start = @alignments[0][0].to_i32
      start.times { original_alignments << {0_u32, 0_u32} } if start > 0

      last_start = @alignments[0][0].to_i32
      last_end = @alignments[0][1].to_i32
      offset = 0
      span_length = 0

      @alignments.each do |(entry_start_u32, entry_end_u32)|
        entry_start = entry_start_u32.to_i32
        entry_end = entry_end_u32.to_i32

        if entry_start == last_start && entry_end == last_end
          span_length += 1
        else
          (last_end - last_start).times { original_alignments << {offset.to_u32, (offset + span_length).to_u32} }
          offset += span_length
          span_length = 1

          gap = entry_start - last_end
          gap.times { original_alignments << {offset.to_u32, offset.to_u32} } if gap > 0
        end

        last_start = entry_start
        last_end = entry_end
      end

      (last_end - last_start).times { original_alignments << {offset.to_u32, (offset + span_length).to_u32} }
      offset += span_length

      trailing_gap = @original.bytesize - original_alignments.size
      trailing_gap.times { original_alignments << {offset.to_u32, offset.to_u32} } if trailing_gap > 0

      original_alignments
    end

    private def lrstrip(left : Bool, right : Bool)
      leading_spaces = left ? @normalized.each_char.take_while(&.whitespace?).size : 0
      trailing_spaces = right ? @normalized.each_char.to_a.reverse.take_while(&.whitespace?).size : 0

      if leading_spaces > 0 || trailing_spaces > 0
        count = @normalized.chars.size
        transformations = [] of Tuple(Char, Int32)

        @normalized.each_char_with_index do |char, index|
          next if index < leading_spaces || index >= count - trailing_spaces

          change = index == count - trailing_spaces - 1 ? -trailing_spaces : 0
          transformations << {char, change}
        end

        transform(transformations, leading_spaces)
      end

      self
    end

    private def normalized_chars_for_form(form : Unicode::NormalizationForm) : Array(Tuple(Char, Int32))
      transformations = [] of Tuple(Char, Int32)

      @normalized.each_char do |char|
        char.to_s.unicode_normalize(form).each_char_with_index do |normalized_char, index|
          transformations << {normalized_char, index == 0 ? 0 : 1}
        end
      end

      transformations
    end

    private def validate_range(range)
      case range
      when Range::Original
        candidate = range.into_full_range(len_original)
        return nil unless char_boundary?(@original, candidate.begin) && char_boundary?(@original, candidate.end)
        Range::Original.new(candidate)
      when Range::Normalized
        candidate = range.into_full_range(length)
        return nil unless char_boundary?(@normalized, candidate.begin) && char_boundary?(@normalized, candidate.end)
        Range::Normalized.new(candidate)
      end
    end

    private def char_boundary?(s : String, index : Int32) : Bool
      return false if index < 0 || index > s.bytesize
      return true if index == 0 || index == s.bytesize

      NormalizedString.byte_char_entries(s).any? { |byte_offset, _| byte_offset == index }
    end

    private def byte_slice(s : String, range : ::Range(Int32, Int32)) : String?
      return nil if range.begin < 0 || range.end < range.begin || range.end > s.bytesize
      s.byte_slice(range.begin, range.end - range.begin)
    end

    def self.byte_char_entries(s : String) : Array(Tuple(Int32, Char))
      entries = [] of Tuple(Int32, Char)
      s.each_char_with_index do |char, char_index|
        entries << {s.char_index_to_byte_index(char_index).not_nil!, char}
      end
      entries
    end
  end

  def self.get_range_of(s : String, range) : String?
    start_idx, end_idx = range_bounds(range, s.chars.size)
    return nil if start_idx < 0 || end_idx < start_idx || end_idx > s.chars.size

    entries = Tokens.byte_char_entries(s)
    start_byte = if start_idx == 0
                   0
                 elsif entry = entries[start_idx]?
                   entry[0]
                 else
                   s.bytesize
                 end

    end_byte = if end_idx == s.chars.size
                 s.bytesize
               elsif entry = entries[end_idx]?
                 entry[0]
               else
                 s.bytesize
               end

    s.byte_slice(start_byte, end_byte - start_byte)
  end

  def self.bytes_to_char(s : String, range : ::Range(Int32, Int32)) : ::Range(Int32, Int32)?
    start = range.begin == 0 && range.end == 0 ? 0 : nil
    finish = range.begin == 0 && range.end == 0 ? 0 : nil

    Tokens.byte_char_entries(s).each_with_index do |(byte_offset, char), index|
      start = index if byte_offset == range.begin
      finish = index if byte_offset == range.end
      finish = index + 1 if byte_offset + char.bytesize == range.end
      break if byte_offset > range.end
    end

    return nil unless start && finish
    start.to_i32...finish.to_i32
  end

  def self.char_to_bytes(s : String, range : ::Range(Int32, Int32)) : ::Range(Int32, Int32)?
    start = range.begin == 0 && range.end == 0 ? 0 : nil
    finish = range.begin == 0 && range.end == 0 ? 0 : nil
    entries = Tokens.byte_char_entries(s)

    if range.begin == range.end
      if entry = entries[range.begin]?
        start = entry[0]
        finish = entry[0]
      elsif range.begin == entries.size
        start = s.bytesize
        finish = s.bytesize
      end
    else
      entries[range.begin...range.end].each do |byte_offset, char|
        start ||= byte_offset
        finish = byte_offset + char.bytesize
      end
    end

    return nil unless start && finish
    start.to_i32...finish.to_i32
  end

  private def self.range_bounds(range, max_len : Int32) : Tuple(Int32, Int32)
    start = range.begin.nil? ? 0 : range.begin.not_nil!.to_i32
    finish = if range.end.nil?
               max_len
             else
               bound = range.end.not_nil!.to_i32
               range.excludes_end? ? bound : bound + 1
             end
    {start, finish}
  end

  def self.byte_char_entries(s : String) : Array(Tuple(Int32, Char))
    entries = [] of Tuple(Int32, Char)
    s.each_char_with_index do |char, char_index|
      entries << {s.char_index_to_byte_index(char_index).not_nil!, char}
    end
    entries
  end
end
