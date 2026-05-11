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
          str_tokens = encode(sequence)
          tokens = [] of Token
          offset = 0

          str_tokens.each do |string|
            len = string.bytesize
            offsets = {offset.to_u32, (offset + len).to_u32}
            id = @token_to_ids[string]?
            if id
              tokens << Token.new(id, string, offsets)
            elsif @byte_fallback
              all_found = true
              byte_results = [] of Token
              string.each_byte do |byte|
                bs = sprintf("<0x%02X>", byte)
                bid = @token_to_ids[bs]?
                if bid
                  byte_results << Token.new(bid, bs, offsets)
                else
                  all_found = false
                  break
                end
              end
              if all_found
                tokens.concat(byte_results)
                offset += len
                next
              end
              # Fallback: use unk
              uid = @unk_id || raise(MissingUnkId.new)
              tokens << Token.new(uid.to_u32, id_to_token(uid.to_u32) || "<unk>", offsets)
            else
              uid = @unk_id || raise(MissingUnkId.new)
              tokens << Token.new(uid.to_u32, id_to_token(uid.to_u32) || "<unk>", offsets)
            end
            offset += len
          end

          tokens
        end

        def encode(sentence : String) : Array(String)
          return [] of String if sentence.empty?

          if @alpha.nil? || @alpha == 0.0
            result = if @is_optimized
                       encode_optimized(sentence)
                     else
                       encode_unoptimized(sentence)
                     end
            result
          else
            encode_unoptimized(sentence)
          end
        end

        private def encode_optimized(sentence : String) : Array(String)
          size = sentence.bytesize
          unk_score = @min_score - K_UNK_PENALTY

          # BestPathNode: stores best path ending at each position
          best_path_score = Array(Float64).new(size + 1, 0.0)
          best_path_starts_at = Array(Int32?).new(size + 1, nil)
          best_path_id = Array(Int32).new(size + 1, 0)

          starts_at = 0
          while starts_at < size
            path_score_till = best_path_score[starts_at]
            has_single_node = false

            # Get byte length of first char at this position
            remaining = sentence.byte_slice(starts_at, size - starts_at) || ""
            mblen = remaining.each_char.first?.try(&.bytesize) || 1

            # Search trie for matching tokens
            candidates = @trie.common_prefix_search(sentence.each_byte.skip(starts_at).each)

            candidates.each do |tok_bytes|
              key_pos = starts_at + tok_bytes.size
              token = String.new(tok_bytes.to_unsafe, tok_bytes.size)
              length = key_pos - starts_at
              id = @token_to_ids[token]
              next unless id
              score = @vocab_entries[id.to_i32][1]
              candidate_score = score + path_score_till

              if best_path_starts_at[key_pos].nil? || candidate_score > best_path_score[key_pos]
                best_path_score[key_pos] = candidate_score
                best_path_starts_at[key_pos] = starts_at
                best_path_id[key_pos] = id.to_i32
              end

              has_single_node = true if !has_single_node && length == mblen
            end

            unless has_single_node
              key_pos = starts_at + mblen
              candidate_score = unk_score + path_score_till
              if best_path_starts_at[key_pos].nil? || candidate_score > best_path_score[key_pos]
                best_path_score[key_pos] = candidate_score
                best_path_starts_at[key_pos] = starts_at
                best_path_id[key_pos] = (@unk_id || raise(MissingUnkId.new))
              end
            end

            starts_at += mblen
          end

          # Backtrack
          ends_at = size
          results = [] of String
          fused = false
          fused_tokens = [] of String

          while ends_at > 0
            start = best_path_starts_at[ends_at] || 0
            if @fuse_unk && best_path_id[ends_at] == @unk_id
              fused_tokens << sentence.byte_slice(start, ends_at - start)
              fused = true
            else
              if !fused_tokens.empty?
                fused_tokens.reverse_each { |t| results << t }
                fused_tokens.clear
                fused = false
              end
              results << (sentence.byte_slice(start, ends_at - start) || "")
            end
            ends_at = start
          end

          unless fused_tokens.empty?
            fused_tokens.reverse_each { |t| results << t }
          end

          results.reverse
        end

        private def encode_unoptimized(sentence : String) : Array(String)
          lattice = Lattice.new(sentence, @bos_id, @eos_id)
          populate_nodes(lattice)
          path = if (n = @nbest_size) && (a = @alpha) && n > 0
                   lattice.nbest(n) # Just take best for now (nbest sampling not ported)
                   lattice.viterbi
                 elsif a = @alpha
                   lattice.viterbi # Sampling not ported; use viterbi
                 else
                   lattice.viterbi
                 end

          results = [] of String
          fused_token = ""

          path.each do |node|
            item = lattice.piece(node)
            if node.id == @unk_id
              fused_token += item
            else
              unless fused_token.empty?
                results << fused_token
                fused_token = ""
              end
              results << item
            end
          end

          unless fused_token.empty?
            results << fused_token
          end

          results
        end

        def populate_nodes(lattice : Lattice) : Nil
          unk_score = @min_score - K_UNK_PENALTY
          llen = lattice.len
          begin_pos = 0

          while begin_pos < llen
            remaining = lattice.sentence.byte_slice(begin_pos, llen - begin_pos) || ""
            mblen = remaining.each_char.first?.try(&.bytesize) || 1
            has_single_node = false

            candidates = @trie.common_prefix_search(lattice.sentence.each_byte.skip(begin_pos).each)

            candidates.each do |tok_bytes|
              n = tok_bytes.size
              tok = String.new(tok_bytes.to_unsafe, tok_bytes.size)
              id = @token_to_ids[tok] || next
              item = @vocab_entries[id.to_i32]
              score = item[1]
              lattice.insert(begin_pos, n, score, id.to_i32)
              has_single_node = true if !has_single_node && n == mblen
            end

            unless has_single_node
              if uid = @unk_id
                lattice.insert(begin_pos, mblen, unk_score, uid)
              end
            end

            begin_pos += mblen
          end
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
