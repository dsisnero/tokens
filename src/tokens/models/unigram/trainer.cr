module Tokens
  module Models
    module Unigram
      alias SentencePiece = Tuple(String, Float64)

      class Unigram
        # digamma function
        def self.digamma(x : Float64) : Float64
          result = 0.0_f64
          mut_x = x
          while mut_x < 7.0
            result -= 1.0 / mut_x
            mut_x += 1.0
          end
          mut_x -= 0.5
          xx = 1.0 / mut_x
          xx2 = xx * xx
          xx4 = xx2 * xx2
          result + Math.log(mut_x) + (1.0 / 24.0) * xx2 - 7.0 / 960.0 * xx4 +
            (31.0 / 8064.0) * xx4 * xx2 - (127.0 / 30720.0) * xx4 * xx4
        end

        def self.to_log_prob(pieces : Array(SentencePiece)) : Nil
          sum = pieces.sum { |(_, score)| score }
          logsum = Math.log(sum)
          pieces.size.times do |i|
            token, score = pieces[i]
            pieces[i] = {token, Math.log(score) - logsum}
          end
        end
      end

      class VocabularyTooSmall < TokenizerError
        def initialize
          super("The vocabulary is not large enough to contain all chars")
        end
      end

      class UnigramTrainer
        include ::Tokens::Trainer(Unigram)

        property show_progress : Bool
        property vocab_size : UInt32
        property n_sub_iterations : UInt32
        property shrinking_factor : Float64
        property special_tokens : Array(AddedToken)
        property initial_alphabet : Set(Char)
        property unk_token : String?
        property max_piece_length : Int32
        property seed_size : Int32
        property words : Hash(String, UInt32)

        def initialize(
          @show_progress = true,
          @vocab_size = 8000_u32,
          @n_sub_iterations = 2_u32,
          @shrinking_factor = 0.75_f64,
          @special_tokens = [] of AddedToken,
          @initial_alphabet = Set(Char).new,
          @unk_token = nil,
          @max_piece_length = 16,
          @seed_size = 1_000_000,
          @words = {} of String => UInt32,
        )
        end

        def should_show_progress? : Bool
          @show_progress
        end

        def train(model : Unigram) : Array(AddedToken)
          sentences = @words.map { |(s, i)| {s, i} }
          do_train(sentences, model)
          @special_tokens
        end

        def feed(strings : Array(String), &process : String -> Array(String))
          strings.each do |sequence|
            words = process.call(sequence)
            words.each do |word|
              @words[word] = (@words[word]? || 0_u32) + 1
            end
          end
        end

        def required_chars(sentences : Array(Tuple(String, UInt32))) : Set(String)
          chars = Set(String).new
          sentences.each { |(s, _)| s.each_char { |c| chars << c.to_s } }
          @initial_alphabet.each { |c| chars << c.to_s }
          chars
        end

        private def valid_piece?(chars : Array(Char)) : Bool
          !chars.empty? && chars.size <= @max_piece_length
        end

        private def make_seeds(sentences : Array(Tuple(String, UInt32))) : Array(SentencePiece)
          counts = {} of String => UInt32
          sentences.each do |(s, c)|
            s.each_char { |ch| key = ch.to_s; counts[key] = (counts[key]? || 0_u32) + c }
            chars = s.chars.to_a
            (1..{@max_piece_length, chars.size}.min).each do |n|
              (0..chars.size - n).each do |i|
                next unless valid_piece?(chars[i, n])
                k = chars[i, n].join
                counts[k] = (counts[k]? || 0_u32) + c
              end
            end
          end

          sorted = counts.to_a.sort_by { |(_, ct)| -(ct.to_i64) }
          pieces = [] of SentencePiece
          seen = Set(String).new
          sorted.each do |(token, ct)|
            break if pieces.size >= @seed_size
            unless seen.includes?(token)
              seen << token
              pieces << {token, ct.to_f64}
            end
          end
          Unigram.to_log_prob(pieces)
          pieces
        end

        private def e_step(model : Unigram, sentences : Array(Tuple(String, UInt32))) : Tuple(Float64, Int32, Array(Float64))
          all_freq = sentences.sum { |(_, c)| c }
          expected = Array(Float64).new(model.vocab_size.to_i32, 0.0)
          objs = 0.0
          ntokens = 0_i32

          sentences.each do |(s, c)|
            lattice = Lattice.new(s, model.bos_id, model.eos_id)
            model.populate_nodes(lattice)
            z = lattice.populate_marginal(c.to_f64, expected)
            ntokens += lattice.viterbi.size
            objs -= z / all_freq.to_f64
          end
          {objs, ntokens, expected}
        end

        private def m_step(pieces : Array(SentencePiece), expected : Array(Float64)) : Array(SentencePiece)
          new_pieces = [] of SentencePiece
          sum = 0.0
          threshold = 0.5

          pieces.each_with_index do |(piece, _), i|
            if i == 0
              new_pieces << {piece, Float64::NAN}
              next
            end
            freq = expected[i]? || 0.0
            next if freq < threshold
            new_pieces << {piece, freq}
            sum += freq
          end

          if new_pieces.size > 1
            logsum = Unigram.digamma(sum)
            new_pieces = new_pieces.map_with_index do |(s, c), i|
              i == 0 ? {s, Float64::NAN} : {s, Unigram.digamma(c) - logsum}
            end
          end
          new_pieces
        end

        private def finalize_vocab(model : Unigram, required_chars : Set(String)) : Unigram
          min_p = 0.0
          delta = 0.0001
          pieces = [] of SentencePiece
          inserted = Set(String).new
          inserted << "<UNK>"
          existing = {} of String => Float64
          model.vocab_entries.each { |(t, s)| existing[t] = s }

          required_chars.each do |c|
            if s = existing[c]?
              inserted << c
              pieces << {c, s}
            else
              s = model.min_score + min_p
              inserted << c
              pieces << {c, s}
              min_p += delta
            end
          end

          need_unk = false
          unk_id = 0
          if unk = @unk_token
            idx = @special_tokens.index { |t| t.content == unk }
            if idx
              unk_id = idx
            else
              need_unk = true
            end
          end

          limit = if need_unk
                    @vocab_size.to_i32 - @special_tokens.size - 1
                  else
                    @vocab_size.to_i32 - @special_tokens.size
                  end

          model.vocab_entries.each do |(token, score)|
            next if inserted.includes?(token)
            inserted << token
            pieces << {token, (score != score) ? 0.0 : score}
            break if pieces.size >= limit
          end

          pieces.sort_by! { |(_, s)| -s }
          sp = @special_tokens.map { |t| {t.content, 0.0_f64} }
          sp.insert(0, {@unk_token.not_nil!, 0.0_f64}) if need_unk
          Unigram.from(sp + pieces, unk_id, model.byte_fallback?)
        end

        private def prune(model : Unigram, pieces : Array(SentencePiece), sentences : Array(Tuple(String, UInt32))) : Array(SentencePiece)
          always = Array(Bool).new(pieces.size, false)
          alts = Array(Array(Int32)).new(pieces.size) { [] of Int32 }
          bos = pieces.size + 1
          eos = pieces.size + 2

          pieces.each_with_index do |(token, _), id|
            if id == 0
              always[id] = true
              next
            end
            lat = Lattice.new(token, bos, eos)
            model.populate_nodes(lat)
            nbs = lat.nbest(2)
            if nbs.size == 1
              always[id] = true
            elsif nbs[0].size >= 2
              always[id] = false
            elsif nbs[0].size == 1
              always[id] = true
              nbs[1].each { |n| alts[id] << n.id }
            end
          end

          freq = Array(Float64).new(pieces.size, 0.0)
          inv = Array(Array(Int32)).new(pieces.size) { [] of Int32 }
          vsum = 0.0

          sentences.each_with_index do |(s, c), i|
            lat = Lattice.new(s, bos, eos)
            model.populate_nodes(lat)
            vsum += c.to_f64
            lat.viterbi.each do |node|
              next if node.id < 0 || node.id >= pieces.size
              freq[node.id] += c.to_f64
              inv[node.id] << i
            end
          end

          sum = freq.sum
          logsum = Math.log(sum)
          new_pieces = [pieces[0]] of SentencePiece
          candidates = [] of Tuple(Int32, Float64)

          pieces.each_with_index do |(token, score), id|
            next if id == 0
            if freq[id] == 0.0 && !always[id]
              next
            elsif alts[id].empty?
              new_pieces << {token, score}
            else
              f = 0.0
              inv[id].each { |n| f += sentences[n][1].to_f64 }
              next if f == 0.0
              f /= vsum
              logprob_sp = Math.log(freq[id]) - logsum
              logsum_alt = Math.log(sum + freq[id] * (alts[id].size - 1).to_f64)
              logprob_alt = alts[id].sum { |n| Math.log(freq[n] + freq[id]) - logsum_alt }
              loss = f * (logprob_sp - logprob_alt)
              next if loss != loss # NaN check
              candidates << {id, loss}
            end
          end

          desired = (@vocab_size.to_i32 * 11) / 10
          pruned = {desired, (pieces.size.to_f64 * @shrinking_factor).to_i32}.max
          candidates.sort_by! { |(_, l)| -l.abs }
          candidates.each do |(id, _)|
            break if new_pieces.size >= pruned
            new_pieces << pieces[id]
          end
          new_pieces
        end

        def do_train(sentences : Array(Tuple(String, UInt32)), model : Unigram) : Nil
          pieces = [{"<UNK>", Float64::NAN}] of SentencePiece
          pieces.concat(make_seeds(sentences))
          required = required_chars(sentences)
          raise VocabularyTooSmall.new if required.size > @vocab_size

          new_model = Unigram.from(pieces.clone, 0, false)
          desired = (@vocab_size.to_i32 * 11) / 10

          loop do
            @n_sub_iterations.times do
              _, _, exp = e_step(new_model, sentences)
              pieces = m_step(pieces, exp)
              new_model = Unigram.from(pieces.clone, 0, false)
            end
            break if pieces.size <= desired
            pieces = prune(new_model, pieces, sentences)
            new_model = Unigram.from(pieces.clone, 0, false)
          end

          final = finalize_vocab(new_model, required)
          model.copy_vocab_from(final)
        end
      end
    end
  end
end
