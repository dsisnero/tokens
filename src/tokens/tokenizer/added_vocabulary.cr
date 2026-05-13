require "json"
require "set"

module Tokens
  struct AddedToken
    include JSON::Serializable

    property content : String
    property single_word : Bool
    property lstrip : Bool
    property rstrip : Bool
    property normalized : Bool
    property special : Bool

    def initialize(
      @content = "",
      @single_word = false,
      @lstrip = false,
      @rstrip = false,
      @normalized = true,
      @special = false,
    )
    end

    def self.from(content : String, special : Bool)
      new(content: content, normalized: !special, special: special)
    end

    def single_word(single_word : Bool) : self
      @single_word = single_word
      self
    end

    def lstrip(lstrip : Bool) : self
      @lstrip = lstrip
      self
    end

    def rstrip(rstrip : Bool) : self
      @rstrip = rstrip
      self
    end

    def normalized(normalized : Bool) : self
      @normalized = normalized
      self
    end

    def special(special : Bool) : self
      @special = special
      self
    end

    def hash : UInt64
      @content.hash
    end

    def ==(other : self) : Bool
      @content == other.content &&
        @single_word == other.single_word &&
        @lstrip == other.lstrip &&
        @rstrip == other.rstrip &&
        @normalized == other.normalized &&
        @special == other.special
    end
  end

  struct AddedTokenWithId
    getter id : UInt32
    getter token : AddedToken

    def initialize(@id : UInt32, @token : AddedToken)
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "id", @id
        json.field "content", @token.content
        json.field "single_word", @token.single_word
        json.field "lstrip", @token.lstrip
        json.field "rstrip", @token.rstrip
        json.field "normalized", @token.normalized
        json.field "special", @token.special
      end
    end

    def self.from_json(json_str : String) : self
      data = JSON.parse(json_str)
      raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
      from_json(data)
    end

    def self.from_json(data : JSON::Any) : self
      raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
      obj = data.as_h

      id = obj["id"]?.try(&.as_i?) || raise(JSON::ParseException.new("Missing id", 0, 0))
      content = obj["content"]?.try(&.as_s?) || raise(JSON::ParseException.new("Missing content", 0, 0))
      single_word = obj["single_word"]?.try(&.as_bool) || false
      lstrip = obj["lstrip"]?.try(&.as_bool) || false
      rstrip = obj["rstrip"]?.try(&.as_bool) || false
      normalized = obj["normalized"]?.try(&.as_bool) || false
      special = obj["special"]?.try(&.as_bool) || false

      token = AddedToken.new(
        content: content,
        single_word: single_word,
        lstrip: lstrip,
        rstrip: rstrip,
        normalized: normalized,
        special: special,
      )
      new(id.to_u32, token)
    end
  end

  class AddedVocabulary
    getter added_tokens_encoder : Hash(String, UInt32)
    getter added_tokens_decoder : Hash(UInt32, AddedToken)

    def initialize
      @added_tokens_encoder = {} of String => UInt32
      @added_tokens_decoder = {} of UInt32 => AddedToken
      @special_tokens_set = Set(String).new
      @normalized_cache = {} of UInt32 => String
      @split_tokens = [] of Tuple(String, UInt32)
      @split_normalized_tokens = [] of Tuple(String, UInt32)
      @encode_special_tokens = false
    end

    def len : Int32
      @added_tokens_encoder.size
    end

    def empty? : Bool
      @added_tokens_encoder.empty?
    end

    def set_encode_special_tokens(value : Bool)
      @encode_special_tokens = value
    end

    def get_encode_special_tokens : Bool
      @encode_special_tokens
    end

    def get_vocab : Hash(String, UInt32)
      @added_tokens_encoder
    end

    def get_added_tokens_decoder : Hash(UInt32, AddedToken)
      @added_tokens_decoder
    end

    def token_to_id(token : String, model : Model) : UInt32?
      @added_tokens_encoder[token]? || model.token_to_id(token)
    end

    def simple_id_to_token(id : UInt32) : String?
      @added_tokens_decoder[id]?.try do |token|
        @normalized_cache[id]? || token.content
      end
    end

    def is_special_token(token : String) : Bool
      @special_tokens_set.includes?(token)
    end

    def is_special_token_id(id : UInt32) : Bool
      @added_tokens_decoder[id]?.try(&.special) || false
    end

    def add_special_tokens(tokens, model : Model, normalizer) : UInt64
      add_tokens(tokens, model, normalizer)
    end

    def add_tokens(tokens, model : Model, normalizer) : UInt64
      ignored = 0_u64
      total = 0_u64
      next_id = next_added_token_id(model)

      tokens.each do |token|
        total += 1
        if token.content.empty?
          ignored += 1
          next
        end

        if existing_id = @added_tokens_encoder[token.content]?
          if @added_tokens_decoder[existing_id]? == token
            ignored += 1
            next
          end
        end

        new_id = token_to_id(token.content, model)
        unless new_id
          new_id = next_id
          next_id += 1
        end

        if token.normalized
          cache_normalized_token(new_id, token.content, normalizer)
        else
          @normalized_cache.delete(new_id)
        end

        @added_tokens_encoder[token.content] = new_id
        @added_tokens_decoder[new_id] = token
      end

      refresh_added_tokens
      total - ignored
    end

    def refresh_normalized_tokens(normalizer)
      @normalized_cache.clear

      @added_tokens_decoder.each do |id, token|
        next unless token.normalized
        cache_normalized_token(id, token.content, normalizer)
      end

      refresh_added_tokens
    end

    def find_matches(sentence : String, patterns : Array(Tuple(String, UInt32))) : Array(Tuple(UInt32?, Tuple(UInt32, UInt32)))
      return [{nil.as(UInt32?), {0_u32, 0_u32}}] if sentence.empty?
      return [{nil.as(UInt32?), {0_u32, sentence.bytesize.to_u32}}] if patterns.empty?

      start_offset = 0
      scan_offset = 0
      splits = [] of Tuple(UInt32?, Tuple(UInt32, UInt32))

      while scan_offset < sentence.bytesize
        match = next_match(sentence, patterns, scan_offset)
        break unless match

        id, start, stop = match
        token = @added_tokens_decoder[id]

        if token.single_word
          left = start == 0 || !ends_with_word(sentence.byte_slice(0, start) || "")
          right = stop == sentence.bytesize || !starts_with_word(sentence.byte_slice(stop, sentence.bytesize - stop) || "")

          unless left && right
            scan_offset = start + 1
            next
          end
        end

        matched_start = start
        matched_stop = stop

        if token.lstrip
          matched_start = {space_leftmost_at_end(sentence.byte_slice(0, start) || ""), start_offset}.max
        end

        if token.rstrip
          matched_stop += space_rightmost_at_start(sentence.byte_slice(stop, sentence.bytesize - stop) || "")
        end

        if start_offset < matched_start
          splits << {nil, {start_offset.to_u32, matched_start.to_u32}}
        end

        splits << {id, {matched_start.to_u32, matched_stop.to_u32}}
        start_offset = matched_stop
        scan_offset = matched_stop
      end

      if start_offset != sentence.bytesize
        splits << {nil, {start_offset.to_u32, sentence.bytesize.to_u32}}
      end

      splits
    end

    def extract_and_normalize(normalizer, sequence : String) : PreTokenizedString
      pretokenized = PreTokenizedString.new(sequence)

      pretokenized.split(->(_idx : Int32, part : NormalizedString) {
        split_with_indices(part, @split_tokens)
      })

      pretokenized.split(->(_idx : Int32, part : NormalizedString) {
        normalizer.try(&.normalize(part))
        split_with_indices(part, @split_normalized_tokens)
      })

      pretokenized
    end

    def encode_special_tokens?
      @encode_special_tokens
    end

    private def next_added_token_id(model : Model) : UInt32
      model_vocab_size = model.vocab_size
      if max_id = @added_tokens_decoder.keys.max?
        if max_id >= model_vocab_size || model_vocab_size == 0_u32
          max_id + 1
        else
          model_vocab_size
        end
      else
        model_vocab_size
      end
    end

    private def cache_normalized_token(id : UInt32, content : String, normalizer)
      return unless normalizer

      normalized = NormalizedString.new(content)
      normalizer.normalize(normalized)
      normed = normalized.get
      if normed != content
        @normalized_cache[id] = normed
      else
        @normalized_cache.delete(id)
      end
    end

    private def refresh_added_tokens
      @special_tokens_set = Set(String).new
      @split_tokens = [] of Tuple(String, UInt32)
      @split_normalized_tokens = [] of Tuple(String, UInt32)

      @added_tokens_decoder.each do |id, token|
        @special_tokens_set << token.content if token.special && !token.content.empty?

        if token.normalized
          pattern = @normalized_cache[id]? || token.content
          @split_normalized_tokens << {pattern, id}
        else
          @split_tokens << {token.content, id}
        end
      end

      @split_tokens.sort_by! { |pattern, id| {-pattern.bytesize, id} }
      @split_normalized_tokens.sort_by! { |pattern, id| {-pattern.bytesize, id} }
    end

    private def split_with_indices(sentence : NormalizedString, patterns : Array(Tuple(String, UInt32))) : Array(Split)
      find_matches(sentence.get, patterns).map do |id, (start_offset, stop_offset)|
        slice = sentence.slice(Range::Normalized.new(start_offset...stop_offset))
        raise "AddedVocabulary bad split" unless slice

        if token_id = id
          value = slice.get
          token = Token.new(token_id, value, {0_u32, value.bytesize.to_u32})
          Split.new(slice, [token])
        else
          Split.new(slice)
        end
      end
    end

    private def next_match(sentence : String, patterns : Array(Tuple(String, UInt32)), offset : Int32) : Tuple(UInt32, Int32, Int32)?
      best_id = nil
      best_start = Int32::MAX
      best_stop = -1

      patterns.each do |pattern, id|
        token = @added_tokens_decoder[id]?
        next unless token
        next if @encode_special_tokens && token.special

        start = sentence.byte_index(pattern, offset)
        next unless start
        stop = start + pattern.bytesize

        if start < best_start || (start == best_start && stop - start > best_stop - best_start)
          best_id = id
          best_start = start
          best_stop = stop
        end
      end

      best_id ? {best_id.as(UInt32), best_start, best_stop} : nil
    end

    private def starts_with_word(sentence : String) : Bool
      sentence.each_char do |char|
        return word_char?(char)
      end
      false
    end

    private def ends_with_word(sentence : String) : Bool
      last_char = nil
      sentence.each_char do |char|
        last_char = char
      end
      last_char ? word_char?(last_char) : false
    end

    private def word_char?(char : Char) : Bool
      char.alphanumeric? || char == '_' || char.mark?
    end

    private def space_leftmost_at_end(sentence : String) : Int32
      boundary = sentence.bytesize
      sentence.chars.reverse_each do |char|
        break unless char.whitespace?
        boundary -= char.bytesize
      end
      boundary
    end

    private def space_rightmost_at_start(sentence : String) : Int32
      bytes = 0
      sentence.each_char do |char|
        break unless char.whitespace?
        bytes += char.bytesize
      end
      bytes
    end

    def to_json(json : JSON::Builder)
      json.array do
        @added_tokens_decoder.each do |id, token|
          obj = AddedTokenWithId.new(id, token)
          obj.to_json(json)
        end
      end
    end
  end
end
