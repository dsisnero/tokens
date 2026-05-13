require "json"

module Tokens
  module Models
    class WordPieceError < TokenizerError
    end

    class WordPieceMissingUnk < WordPieceError
      def initialize
        super("WordPiece error: Missing [UNK] token from the vocabulary")
      end
    end

    class WordPiece
      include Model

      getter vocab : Hash(String, UInt32)
      getter vocab_r : Hash(UInt32, String)
      getter unk_token : String
      getter continuing_subword_prefix : String
      getter max_input_chars_per_word : UInt32

      def initialize(
        @vocab = {} of String => UInt32,
        @vocab_r = {} of UInt32 => String,
        @unk_token = "[UNK]",
        @continuing_subword_prefix = "##",
        @max_input_chars_per_word = 100_u32,
      )
      end

      def self.default : self
        new
      end

      def self.build(
        vocab : Hash(String, UInt32),
        unk_token : String = "[UNK]",
        continuing_subword_prefix : String = "##",
        max_input_chars_per_word : UInt32 = 100_u32,
      ) : self
        vocab_r = {} of UInt32 => String
        vocab.each { |key, val| vocab_r[val] = key }
        new(vocab, vocab_r, unk_token, continuing_subword_prefix, max_input_chars_per_word)
      end

      def tokenize(sequence : String) : Array(Token)
        char_count = sequence.size

        if char_count > @max_input_chars_per_word
          unk_id = @vocab[@unk_token]? || raise(WordPieceMissingUnk.new)
          return [Token.new(unk_id, @unk_token, {0_u32, sequence.bytesize.to_u32})]
        end

        is_bad = false
        start = 0
        sub_tokens = [] of Token

        while start < sequence.bytesize
          end_pos = sequence.bytesize
          cur_token = nil

          while start < end_pos
            substr = sequence.byte_slice(start, end_pos - start) || ""

            lookup = if start > 0
                       "#{@continuing_subword_prefix}#{substr}"
                     else
                       substr
                     end

            if id = @vocab[lookup]?
              cur_token = Token.new(id, lookup, {start.to_u32, end_pos.to_u32})
              break
            end

            # Move end_pos back by the byte length of the last character
            char_bytes = 1
            if end_pos > start
              # Find the byte start of the last char
              byte_idx = end_pos - 1
              while byte_idx > start && (sequence.byte_at(byte_idx) & 0xC0) == 0x80
                byte_idx -= 1
              end
              end_pos = byte_idx
            else
              end_pos -= 1
            end
          end

          if cur_token.nil?
            is_bad = true
            break
          end

          sub_tokens << cur_token
          start = end_pos
        end

        if is_bad
          unk_id = @vocab[@unk_token]? || raise(WordPieceMissingUnk.new)
          [Token.new(unk_id, @unk_token, {0_u32, sequence.bytesize.to_u32})]
        else
          sub_tokens
        end
      end

      def token_to_id(token : String) : UInt32?
        @vocab[token]?
      end

      def id_to_token(id : UInt32) : String?
        @vocab_r[id]?
      end

      def vocab : Hash(String, UInt32)
        @vocab.dup
      end

      def vocab_size : UInt32
        @vocab.size.to_u32
      end

      def save(folder : String, name : String? = nil) : Array(String)
        file_name = name ? "#{name}-vocab.txt" : "vocab.txt"
        path = File.join(folder, file_name)

        sorted = @vocab.to_a.sort_by { |(_, id)| id }
        File.open(path, "w") do |f|
          sorted.each { |(token, _)| f.puts token }
        end
        [path]
      end

      def trainer
        WordPieceTrainer.default
      end

      def self.read_file(path : String) : Hash(String, UInt32)
        vocab = {} of String => UInt32
        File.each_line(path) do |line|
          vocab[line.rstrip('\n').strip] = vocab.size.to_u32
        end
        vocab
      end

      def self.from_bpe(bpe : Tokens::Models::BPE::BPE) : self
        wp = build(vocab: bpe.vocab)
        if unk = bpe.unk_token
          wp = build(vocab: wp.vocab, unk_token: unk)
        end
        if prefix = bpe.continuing_subword_prefix
          wp = build(vocab: wp.vocab, unk_token: wp.unk_token, continuing_subword_prefix: prefix)
        end
        wp
      end

      def copy_vocab_from(other : self)
        @vocab = other.vocab
        @vocab_r = other.vocab_r
        @continuing_subword_prefix = other.continuing_subword_prefix
      end

      def ==(other : self) : Bool
        @vocab == other.vocab && @unk_token == other.unk_token &&
          @continuing_subword_prefix == other.continuing_subword_prefix &&
          @max_input_chars_per_word == other.max_input_chars_per_word
      end

      def to_json : String
        String.build do |io|
          JSON.build(io) do |json|
            json.object do
              json.field "type", "WordPiece"
              json.field "unk_token", @unk_token
              json.field "continuing_subword_prefix", @continuing_subword_prefix
              json.field "max_input_chars_per_word", @max_input_chars_per_word
              json.field "vocab" do
                json.object do
                  max = @vocab_r.keys.max? || 0_u32
                  (0_u32..max).each do |i|
                    if token = @vocab_r[i]?
                      json.field token, i
                    end
                  end
                end
              end
            end
          end
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

        if type = obj["type"]?.try(&.as_s?)
          unless type == "WordPiece"
            raise JSON::ParseException.new("invalid value: string \"#{type}\", expected WordPiece", 0, 0)
          end
        end

        unk = obj["unk_token"]?.try(&.as_s?)
        raise JSON::ParseException.new("missing field `unk_token`", 0, 0) unless unk

        prefix = obj["continuing_subword_prefix"]?.try(&.as_s?)
        raise JSON::ParseException.new("missing field `continuing_subword_prefix`", 0, 0) unless prefix

        max_chars = obj["max_input_chars_per_word"]?.try(&.as_i?)
        raise JSON::ParseException.new("missing field `max_input_chars_per_word`", 0, 0) unless max_chars

        vocab_val = obj["vocab"]?
        raise JSON::ParseException.new("missing field `vocab`", 0, 0) unless vocab_val
        raise JSON::ParseException.new("Expected vocab object", 0, 0) unless vocab_val.as_h?

        vocab = {} of String => UInt32
        vocab_val.as_h.each { |token, id| vocab[token] = id.as_i.to_u32 }

        build(
          vocab: vocab,
          unk_token: unk,
          continuing_subword_prefix: prefix,
          max_input_chars_per_word: max_chars.to_u32
        )
      end
    end
  end
end
