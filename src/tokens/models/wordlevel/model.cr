require "json"

module Tokens
  module Models
    class WordLevelError < TokenizerError
    end

    class WordLevelMissingUnk < WordLevelError
      def initialize
        super("WordLevel error: Missing [UNK] token from the vocabulary")
      end
    end

    class WordLevel
      include Model

      getter vocab : Hash(String, UInt32)
      getter vocab_r : Hash(UInt32, String)
      getter unk_token : String

      def initialize(
        @vocab = {} of String => UInt32,
        @vocab_r = {} of UInt32 => String,
        @unk_token = "<unk>",
      )
      end

      def self.default : self
        new
      end

      def self.build(vocab : Hash(String, UInt32), unk_token : String = "<unk>") : self
        vocab_r = {} of UInt32 => String
        vocab.each { |key, val| vocab_r[val] = key }
        new(vocab, vocab_r, unk_token)
      end

      def tokenize(sequence : String) : Array(Token)
        if id = @vocab[sequence]?
          [Token.new(id, sequence, {0_u32, sequence.bytesize.to_u32})]
        elsif unk_id = @vocab[@unk_token]?
          [Token.new(unk_id, @unk_token, {0_u32, sequence.bytesize.to_u32})]
        else
          raise WordLevelMissingUnk.new
        end
      end

      def token_to_id(token : String) : UInt32?
        @vocab[token]?
      end

      def id_to_token(id : UInt32) : String?
        @vocab_r[id]?
      end

      def vocab_set(v : Hash(String, UInt32))
        @vocab = v
      end

      def vocab_r_set(v : Hash(UInt32, String))
        @vocab_r = v
      end

      def vocab : Hash(String, UInt32)
        @vocab.dup
      end

      def vocab_size : UInt32
        @vocab.size.to_u32
      end

      def save(folder : String, name : String? = nil) : Array(String)
        file_name = name ? "#{name}-vocab.json" : "vocab.json"
        path = File.join(folder, file_name)
        File.write(path, to_json)
        [path]
      end

      def trainer
        WordLevelTrainer.default
      end

      def ==(other : self) : Bool
        @vocab == other.vocab && @unk_token == other.unk_token
      end

      def to_json : String
        String.build do |io|
          JSON.build(io) do |json|
            json.object do
              json.field "type", "WordLevel"
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
              json.field "unk_token", @unk_token
            end
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
        obj = data.as_h

        # Validate type
        if type = obj["type"]?.try(&.as_s?)
          unless type == "WordLevel"
            raise JSON::ParseException.new("invalid value: string \"#{type}\", expected WordLevel", 0, 0)
          end
        end

        unk = obj["unk_token"]?.try(&.as_s?)
        raise JSON::ParseException.new("missing field `unk_token`", 0, 0) unless unk

        vocab_val = obj["vocab"]?
        raise JSON::ParseException.new("missing field `vocab`", 0, 0) unless vocab_val

        raise JSON::ParseException.new("Expected vocab object", 0, 0) unless vocab_val.as_h?
        vocab = {} of String => UInt32
        vocab_val.as_h.each do |token, id|
          vocab[token] = id.as_i.to_u32
        end

        build(vocab: vocab, unk_token: unk)
      end
    end
  end
end
