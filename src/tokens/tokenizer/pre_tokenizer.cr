module Tokens
  class Split
    getter normalized : NormalizedString
    property tokens : Array(Token)?

    def initialize(@normalized : NormalizedString, @tokens : Array(Token)? = nil)
    end

    def ==(other : self) : Bool
      @normalized == other.normalized && @tokens == other.tokens
    end

    def clone : self
      self.class.new(@normalized.clone, @tokens.try(&.dup))
    end
  end

  class PreTokenizedString
    getter original : String
    getter splits : Array(Split)

    def initialize(@original = "", @splits = [] of Split)
    end

    def initialize(normalized : NormalizedString)
      @original = normalized.get_original.dup
      @splits = [Split.new(normalized)]
    end

    def ==(other : self) : Bool
      @original == other.original && @splits == other.splits
    end

    def clone : self
      self.class.new(@original.dup, @splits.map(&.clone))
    end

    def self.new(s : String)
      normalized = NormalizedString.new(s)
      new(normalized)
    end

    def split(split_fn : Int32, NormalizedString -> Array(Split))
      new_splits = [] of Split
      @splits.each_with_index do |split, i|
        if split.tokens
          new_splits << split
          next
        end

        split_fn.call(i, split.normalized).each do |s|
          new_splits << s unless s.normalized.empty?
        end
      end
      @splits = new_splits
    end

    def split(&block : Int32, NormalizedString -> Array(Split))
      split(block)
    end

    def normalize(normalize_fn : NormalizedString -> Nil)
      @splits.each do |split|
        next if split.tokens
        normalize_fn.call(split.normalized)
      end
    end

    def normalize(&block : NormalizedString -> Nil)
      normalize(block)
    end

    def tokenize(tokenize_fn : NormalizedString -> Array(Token))
      @splits.each do |split|
        next if split.tokens
        split.tokens = tokenize_fn.call(split.normalized)
      end
    end

    def tokenize_with_limit(tokenize_fn : NormalizedString -> Array(Token), max_tokens : Int32, direction : TruncationDirection)
      total_tokens = 0

      case direction
      when TruncationDirection::Left
        first_tokenized_idx = @splits.size
        (@splits.size - 1).downto(0) do |i|
          split = @splits[i]
          if tokens = split.tokens
            total_tokens += tokens.size
            first_tokenized_idx = i
            next
          end

          tokens = tokenize_fn.call(split.normalized)
          total_tokens += tokens.size
          split.tokens = tokens
          first_tokenized_idx = i
          break if total_tokens >= max_tokens
        end
        @splits = @splits[first_tokenized_idx..]
      when TruncationDirection::Right
        last_tokenized_idx = 0
        @splits.each_with_index do |split, i|
          if tokens = split.tokens
            total_tokens += tokens.size
            last_tokenized_idx = i + 1
            next
          end

          tokens = tokenize_fn.call(split.normalized)
          total_tokens += tokens.size
          split.tokens = tokens
          last_tokenized_idx = i + 1
          break if total_tokens >= max_tokens
        end
        @splits = @splits[...last_tokenized_idx]
      end
    end

    def into_encoding(word_idx : UInt32?, type_id : UInt32, offset_type : OffsetType) : Encoding
      return Encoding.new if @splits.empty?

      @splits.each { |s| raise "Split has not been tokenized" unless s.tokens }

      case offset_type
      when OffsetType::None
        tokens = @splits.flat_map { |split|
          (split.tokens || [] of Token).map { |token|
            {token.id, String.new, {0_u32, 0_u32}, nil, 0_u32}
          }
        }
        Encoding.new(
          ids: tokens.map { |(id, _, _, _, _)| id },
          tokens: tokens.map { |(_, t, _, _, _)| t },
          offsets: tokens.map { |(_, _, o, _, _)| o },
          words: tokens.map { |(_, _, _, w, _)| w },
          type_ids: tokens.map { |(_, _, _, _, t)| t },
          attention_mask: Array(UInt32).new(tokens.size, 1_u32),
          special_tokens_mask: Array(UInt32).new(tokens.size, 0_u32)
        )
      when OffsetType::Byte
        token_entries = [] of Tuple(UInt32, String, Tuple(UInt32, UInt32), UInt32?, UInt32)
        @splits.each_with_index do |split, idx|
          norm = split.normalized
          offsets_orig = norm.offsets_original
          (split.tokens || [] of Token).each do |token|
            token_offsets = norm.convert_offsets(Range::Normalized.new(token.offsets[0]...token.offsets[1]))
            final_offsets = if to = token_offsets
                              {offsets_orig[0] + to.begin.to_u32, offsets_orig[0] + to.end.to_u32}
                            else
                              token.offsets
                            end
            token_entries << {token.id, token.value, final_offsets, word_idx || idx.to_u32, type_id}
          end
        end

        Encoding.new(
          ids: token_entries.map { |(id, _, _, _, _)| id },
          tokens: token_entries.map { |(_, value, _, _, _)| value },
          offsets: token_entries.map { |(_, _, offsets, _, _)| offsets },
          words: token_entries.map { |(_, _, _, word, _)| word },
          type_ids: token_entries.map { |(_, _, _, _, token_type)| token_type },
          attention_mask: Array(UInt32).new(token_entries.size, 1_u32),
          special_tokens_mask: Array(UInt32).new(token_entries.size, 0_u32)
        )
      when OffsetType::Char
        into_encoding(word_idx, type_id, OffsetType::Byte)
      else
        Encoding.new
      end
    end

    def get_splits(offset_ref : OffsetReferential, offset_type : OffsetType) : Array(Tuple(String, Tuple(UInt32, UInt32), Array(Token)?))
      offset_converter = case offset_type
                         when OffsetType::Char
                           BytesToCharOffsetConverter.new(@original)
                         else
                           nil
                         end

      offset = 0_u32
      @splits.map { |split|
        offsets = {0_u32, 0_u32}
        case offset_ref
        when OffsetReferential::Original
          offsets = split.normalized.offsets_original
        when OffsetReferential::Normalized
          len = split.normalized.length.to_u32
          prev = offset
          offset += len
          offsets = {prev, offset}
        end

        if converter = offset_converter
          offsets = converter.convert(offsets) || offsets
        end

        {split.normalized.get, offsets, split.tokens}
      }
    end
  end

  struct BytesToCharOffsetConverter
    def initialize(sequence : String)
      @map = {} of UInt32 => UInt32
      char_index = 0_u32
      sequence.each_char_with_index do |char, _|
        byte_start = sequence.char_index_to_byte_index(char_index.to_i32)
        next unless byte_start

        char.bytesize.times do |offset|
          @map[(byte_start + offset).to_u32] = char_index
        end

        char_index += 1
      end
    end

    def convert(offsets : Tuple(UInt32, UInt32)) : Tuple(UInt32, UInt32)?
      start = @map[offsets[0]]?
      end_offset = @map[offsets[1]]?
      return nil unless start

      if end_offset
        {start, end_offset}
      elsif offsets[1] > 0
        last = @map[(offsets[1] - 1).to_u32]? || (start + 1)
        {start, last + 1}
      else
        {start, start}
      end
    end
  end
end
