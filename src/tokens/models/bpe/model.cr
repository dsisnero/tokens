module Tokens
  module Models
    module BPE
      class BPE
        include Model

        property vocab : Vocab
        property vocab_r : VocabR
        property merges : MergeMap
        property dropout : Float32?
        property unk_token : String?
        property continuing_subword_prefix : String?
        property end_of_word_suffix : String?
        property? fuse_unk : Bool
        property? byte_fallback : Bool
        property? ignore_merges : Bool

        def initialize(
          @vocab : Vocab,
          @vocab_r : VocabR,
          @merges : MergeMap,
          @cache : BpeCache?,
          @dropout : Float32?,
          @unk_token : String?,
          @continuing_subword_prefix : String?,
          @end_of_word_suffix : String?,
          @fuse_unk : Bool,
          @byte_fallback : Bool,
          @ignore_merges : Bool,
        )
        end

        def self.builder : BpeBuilder
          BpeBuilder.new
        end

        def self.build(& : BpeBuilder -> BpeBuilder) : BPE
          builder = BpeBuilder.new
          yield(builder)
          builder.build
        end

        def self.new(vocab : Vocab, merges : Merges) : BPE
          builder.vocab_and_merges(vocab, merges).build
        end

        def self.from_file(vocab_file : String, merges_file : String) : BpeBuilder
          builder.files(vocab_file, merges_file)
        end

        def self.read_file(vocab_file : String, merges_file : String) : {Vocab, Merges}
          vocab_str = File.read(vocab_file)
          vocab = Vocab.new
          parsed = JSON.parse(vocab_str)
          raise BadVocabulary.new unless parsed.is_a?(JSON::Any) && parsed.as_h?
          parsed.as_h.each do |token, id|
            vocab[token] = id.as_i.to_u32
          end

          merges_lines = File.read_lines(merges_file)
          merges = [] of Tuple(String, String)
          merges_lines.each do |line|
            next if line.starts_with?("#version")
            parts = line.split(' ')
            if parts.size != 2
              raise BadMerges.new(merges.size + 1)
            end
            merges << {parts[0], parts[1]}
          end

          {vocab, merges}
        end

        def self.from_json(json_string : String) : BPE
          parsed = JSON.parse(json_string).as_h
          vocab = Vocab.new
          parsed["vocab"].as_h.each do |token, id|
            vocab[token] = id.as_i.to_u32
          end
          merges = parse_merges_from_json(parsed["merges"])
          builder = BpeBuilder.new
          builder.vocab_and_merges(vocab, merges)

          if v = parsed["dropout"]?
            if val = v.as_f?
              builder.dropout(val.to_f32)
            end
          end
          if v = parsed["unk_token"]?
            if val = v.as_s?
              builder.unk_token(val)
            end
          end
          if v = parsed["continuing_subword_prefix"]?
            if val = v.as_s?
              builder.continuing_subword_prefix(val)
            end
          end
          if v = parsed["end_of_word_suffix"]?
            if val = v.as_s?
              builder.end_of_word_suffix(val)
            end
          end
          if v = parsed["fuse_unk"]?
            builder.fuse_unk(v.as_bool)
          end
          if v = parsed["byte_fallback"]?
            builder.byte_fallback(v.as_bool)
          end
          if v = parsed["ignore_merges"]?
            builder.ignore_merges(v.as_bool)
          end

          builder.build
        end

        private def self.parse_merges_from_json(merges_json : JSON::Any) : Array(Tuple(String, String))
          merges = [] of Tuple(String, String)
          merges_json.as_a.each do |entry|
            case entry
            when JSON::Any
              if entry.raw.is_a?(Array)
                arr = entry.as_a
                if arr.size != 2
                  raise BadMerges.new(0)
                end
                merges << {arr[0].as_s, arr[1].as_s}
              elsif entry.raw.is_a?(String)
                merge_str = entry.as_s
                parts = merge_str.split(' ')
                if parts.size != 2
                  raise BadMerges.new(0)
                end
                merges << {parts[0], parts[1]}
              end
            end
          end
          merges
        end

        def clear_cache
          @cache.try(&.clear)
        end

        def resize_cache(capacity : Int32)
          @cache.try(&.resize(capacity))
        end

        def unk_token : String?
          @unk_token
        end

        def continuing_subword_prefix : String?
          @continuing_subword_prefix
        end

        def to_json : String
          String.build do |io|
            JSON.build(io) do |json|
              json.object do
                json.field("type", "BPE")
                json.field("dropout") { if v = @dropout
                  json.number(v)
                else
                  json.null
                end }
                json.field("unk_token") { if v = @unk_token
                  json.string(v)
                else
                  json.null
                end }
                json.field("continuing_subword_prefix") { if v = @continuing_subword_prefix
                  json.string(v)
                else
                  json.null
                end }
                json.field("end_of_word_suffix") { if v = @end_of_word_suffix
                  json.string(v)
                else
                  json.null
                end }
                json.field("fuse_unk", @fuse_unk)
                json.field("byte_fallback", @byte_fallback)
                json.field("ignore_merges", @ignore_merges)
                json.field("vocab") { json.raw(vocab_as_ordered_json) }
                json.field("merges") do
                  json.array do
                    sorted_merges.each do |(token_a, token_b)|
                      json.array do
                        json.string(token_a)
                        json.string(token_b)
                      end
                    end
                  end
                end
              end
            end
          end
        end

        def vocab_as_ordered_json : String
          String.build do |io|
            JSON.build(io) do |json|
              json.object do
                max = @vocab_r.keys.max? || 0_u32
                (0_u32..max).each do |i|
                  if token = @vocab_r[i]?
                    json.field(token, i)
                  end
                end
              end
            end
          end
        end

        private def sorted_merges : Array(Tuple(String, String))
          @merges.to_a.sort_by { |(_, (rank, _))| rank }.map do |(pair, (_, _))|
            {@vocab_r[pair[0]] || "", @vocab_r[pair[1]] || ""}
          end
        end

        def tokenize(sequence : String) : Array(Token)
          return [] of Token if sequence.empty?

          if @dropout.nil? || @dropout == 0.0_f32
            tokenize_with_cache(sequence)
          else
            word = merge_word(sequence)
            word_to_tokens(word)
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

        def clone : BPE
          fresh_cache = @cache.try(&.fresh)
          BPE.new(
            @vocab.dup, @vocab_r.dup, @merges.dup,
            fresh_cache, @dropout, @unk_token,
            @continuing_subword_prefix, @end_of_word_suffix,
            @fuse_unk, @byte_fallback, @ignore_merges,
          )
        end

        def ==(other : BPE) : Bool
          @vocab == other.vocab &&
            @vocab_r == other.vocab_r &&
            @merges == other.merges &&
            @dropout == other.dropout &&
            @unk_token == other.unk_token &&
            @continuing_subword_prefix == other.continuing_subword_prefix &&
            @end_of_word_suffix == other.end_of_word_suffix &&
            @fuse_unk == other.fuse_unk &&
            @byte_fallback == other.byte_fallback &&
            @ignore_merges == other.ignore_merges
        end

        def save(folder : String, name : String? = nil) : Array(String)
          vocab_file_name = name ? "#{name}-vocab.json" : "vocab.json"
          merges_file_name = name ? "#{name}-merges.txt" : "merges.txt"

          vocab_path = File.join(folder, vocab_file_name)
          File.write(vocab_path, vocab_as_ordered_json)

          merges_path = File.join(folder, merges_file_name)
          File.open(merges_path, "w") do |file|
            file.puts "#version: 0.2"
            sorted_merges.each do |(token_a, token_b)|
              file.puts "#{token_a} #{token_b}"
            end
          end

          [vocab_path, merges_path]
        end

        def trainer
          BpeTrainer.builder
        end

        # ameba:disable Metrics/CyclomaticComplexity
        private def merge_word(w : String) : Word
          chars = w.chars.to_a
          word = Word.with_capacity(w.bytesize.to_i32)
          unk = nil

          chars.each_with_index do |char, index|
            is_first = index == 0
            is_last = index == chars.size - 1

            s = char.to_s
            byte_len = char.bytesize.to_u32

            if !is_first
              if prefix = @continuing_subword_prefix
                s = prefix + s
              end
            end

            if is_last
              if suffix = @end_of_word_suffix
                s = s + suffix
              end
            end

            if id = @vocab[s]?
              if unk_val = unk
                word.add(unk_val[0], unk_val[1])
                unk = nil
              end
              word.add(id, byte_len)
            else
              if @byte_fallback
                found = true
                byte_tokens = [] of UInt32
                s.each_byte do |b|
                  code = String.build { |io| io << "<0x" << b.to_s(16).rjust(2, '0').upcase << ">" }
                  if tid = @vocab[code]?
                    byte_tokens << tid
                  else
                    found = false
                    break
                  end
                end
                if found
                  byte_tokens.each { |tid| word.add(tid, 1_u32) }
                  next
                end
              end

              if unk_token = @unk_token
                unk_id = @vocab[unk_token]
                if unk_id.nil?
                  raise UnkTokenOutOfVocabulary.new(unk_token)
                end

                unk = if prev = unk
                        prev_id, prev_len = prev
                        if @fuse_unk
                          {prev_id, prev_len + byte_len}
                        else
                          word.add(prev_id, prev_len)
                          {unk_id, byte_len}
                        end
                      else
                        {unk_id, byte_len}
                      end
              end
            end
          end

          if unk_val = unk
            word.add(unk_val[0], unk_val[1])
          end

          word.merge_all(@merges, @dropout)
          word
        end

        private def word_to_tokens(word : Word) : Array(Token)
          chars = word.chars_iter.to_a
          offsets = word.offsets_iter.to_a
          chars.zip(offsets).map do |id, offset|
            Token.new(id, @vocab_r[id] || "?", offset)
          end
        end

        private def tokenize_with_cache(sequence : String) : Array(Token)
          if @ignore_merges
            if id = @vocab[sequence]?
              return [Token.new(id, sequence, {0_u32, sequence.bytesize.to_u32})]
            end
          end

          cache = @cache
          if cache.nil?
            word = merge_word(sequence)
            return word_to_tokens(word)
          end

          if hit = cache.get(sequence)
            return word_to_tokens(hit)
          end

          word = merge_word(sequence)
          tokens = word_to_tokens(word)
          if sequence.bytesize < MAX_CACHE_LENGTH
            cache.set(sequence, word)
          end
          tokens
        end
      end
    end
  end
end
