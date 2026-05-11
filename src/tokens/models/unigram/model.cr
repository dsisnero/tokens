require "json"

module Tokens
  module Models
    module Unigram
      class UnigramError < TokenizerError
      end

      class EmptyVocabulary < UnigramError
        def initialize
          super("The vocabulary is empty but at least <unk> is needed")
        end
      end

      class UnkIdNotInVocabulary < UnigramError
        def initialize
          super("The unk_id is larger than vocabulary size")
        end
      end

      class MissingUnkId < UnigramError
        def initialize
          super("Encountered an unknown token but unk_id is missing")
        end
      end

      K_UNK_PENALTY = 10.0_f64

      class Unigram
        include Model

        getter vocab_entries : Array(Tuple(String, Float64))
        getter token_to_ids : Hash(String, UInt32)
        getter trie : Trie(UInt8)
        getter min_score : Float64
        getter unk_id : Int32?
        getter bos_id : Int32
        getter eos_id : Int32
        getter? byte_fallback : Bool
        property alpha : Float64?
        property nbest_size : Int32?

        @fuse_unk : Bool
        @is_optimized : Bool

        def initialize(
          @vocab_entries : Array(Tuple(String, Float64)),
          @token_to_ids : Hash(String, UInt32),
          @trie : Trie(UInt8),
          @min_score : Float64,
          @unk_id : Int32?,
          @bos_id : Int32,
          @eos_id : Int32,
          @byte_fallback : Bool = false,
          @fuse_unk : Bool = true,
          @is_optimized : Bool = true,
          @alpha : Float64? = nil,
          @nbest_size : Int32? = nil,
        )
        end

        def self.default : self
          entries = [{"<unk>", 0.0_f64}] of Tuple(String, Float64)
          from(entries, 0, false)
        end

        def self.from(entries : Array(Tuple(String, Float64)), unk_id : Int32?, byte_fallback : Bool) : self
          n = entries.size
          token_to_ids = {} of String => UInt32
          trie = Trie(UInt8).new
          min_score = Float64::INFINITY

          if unk_id
            if entries.empty?
              raise EmptyVocabulary.new
            end
            if unk_id >= n
              raise UnkIdNotInVocabulary.new
            end
          end

          bos_id = n + 1
          eos_id = n + 2

          entries.each_with_index do |(token, score), id|
            token_to_ids[token] = id.to_u32
            trie.push(token.bytes.to_a)
            min_score = score if score < min_score
          end

          new(
            vocab_entries: entries,
            token_to_ids: token_to_ids,
            trie: trie,
            min_score: min_score,
            unk_id: unk_id,
            bos_id: bos_id,
            eos_id: eos_id,
            byte_fallback: byte_fallback,
            fuse_unk: true,
            is_optimized: true,
          )
        end

        def tokenize(sequence : String) : Array(Token)
          return [] of Token if sequence.empty?

          result = [] of Token
          pos = 0

          while pos < sequence.bytesize
            candidates = trie.common_prefix_search(sequence.each_byte.skip(pos).each)

            best_len = 0
            best_id = nil
            best_token = nil

            candidates.each do |bytes|
              slice = String.new(bytes.to_unsafe, bytes.size)
              if id = token_to_ids[slice]?
                if bytes.size > best_len
                  best_len = bytes.size
                  best_id = id
                  best_token = slice
                end
              end
            end

            if best_token && best_id
              result << Token.new(best_id, best_token, {pos.to_u32, (pos + best_len).to_u32})
              pos += best_len
            else
              if uid = unk_id
                char_len = 1
                if pos < sequence.bytesize
                  char_len = utf8_char_len(sequence.byte_at(pos) || 0_u8)
                end
                unk = id_to_token(uid.to_u32) || "<unk>"
                result << Token.new(uid.to_u32, unk, {pos.to_u32, (pos + char_len).to_u32})
                pos += char_len
              else
                raise MissingUnkId.new
              end
            end
          end

          result
        end

        def token_to_id(token : String) : UInt32?
          @token_to_ids[token]?
        end

        def id_to_token(id : UInt32) : String?
          @vocab_entries[id.to_i32]?.try { |item| item[0] }
        end

        def vocab : Hash(String, UInt32)
          @token_to_ids.dup
        end

        def vocab_size : UInt32
          @vocab_entries.size.to_u32
        end

        def save(folder : String, name : String? = nil) : Array(String)
          file_name = name ? "#{name}-unigram.json" : "unigram.json"
          path = File.join(folder, file_name)
          File.write(path, to_json)
          [path]
        end

        def trainer
          raise "UnigramTrainer not yet ported"
        end

        def ==(other : self) : Bool
          @unk_id == other.unk_id &&
            @vocab_entries == other.vocab_entries &&
            @alpha == other.alpha &&
            @nbest_size == other.nbest_size
        end

        def to_json : String
          String.build do |io|
            JSON.build(io) do |json|
              json.object do
                json.field "type", "Unigram"
                json.field "unk_id" do
                  if id = @unk_id
                    json.number(id)
                  else
                    json.null
                  end
                end
                json.field "vocab" do
                  json.array do
                    @vocab_entries.each do |(token, score)|
                      json.array do
                        json.string token
                        json.number score
                      end
                    end
                  end
                end
                json.field "byte_fallback", @byte_fallback
              end
            end
          end
        end

        def self.from_json(json_str : String) : self
          data = JSON.parse(json_str)
          raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
          obj = data.as_h

          if type = obj["type"]?.try(&.as_s?)
            unless type == "Unigram"
              raise JSON::ParseException.new("invalid value: string \"#{type}\", expected Unigram", 0, 0)
            end
          end

          vocab_raw = obj["vocab"]?
          raise JSON::ParseException.new("Missing vocab", 0, 0) unless vocab_raw
          raise JSON::ParseException.new("Expected vocab array", 0, 0) unless vocab_raw.as_a?

          entries = vocab_raw.as_a.map do |entry|
            arr = entry.as_a
            {arr[0].as_s, arr[1].as_f.to_f64}
          end

          unk_id_raw = obj["unk_id"]?
          unk_id = if unk_id_raw && !unk_id_raw.raw.nil?
                     unk_id_raw.as_i
                   end

          byte_fallback = obj["byte_fallback"]?.try(&.as_bool) || false

          from(entries, unk_id, byte_fallback)
        end

        private def utf8_char_len(byte : UInt8) : Int32
          if byte & 0x80 == 0
            1
          elsif byte & 0xE0 == 0xC0
            2
          elsif byte & 0xF0 == 0xE0
            3
          else
            4
          end
        end
      end
    end
  end
end
