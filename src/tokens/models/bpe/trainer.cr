module Tokens
  module Models
    module BPE
      struct TrainerMerge
        getter pair : Pair
        getter count : UInt64
        getter pos : Set(Int32)

        def initialize(@pair : Pair, @count : UInt64, @pos : Set(Int32))
        end
      end

      class BpeTrainer
        include ::Tokens::Trainer(BPE)

        getter min_frequency : UInt64
        getter vocab_size : Int32
        getter show_progress : Bool
        getter special_tokens : Array(AddedToken)
        getter limit_alphabet : Int32?
        getter initial_alphabet : Set(Char)
        getter continuing_subword_prefix : String?
        getter end_of_word_suffix : String?
        getter max_token_length : Int32?
        getter words : Hash(String, UInt64)

        def initialize(
          @min_frequency : UInt64,
          @vocab_size : Int32,
          @show_progress : Bool,
          @special_tokens : Array(AddedToken),
          @limit_alphabet : Int32?,
          @initial_alphabet : Set(Char),
          @continuing_subword_prefix : String?,
          @end_of_word_suffix : String?,
          @max_token_length : Int32?,
          @words : Hash(String, UInt64),
        )
        end

        def self.builder : BpeTrainerBuilder
          BpeTrainerBuilder.new
        end

        def get_word_count : Int32
          @words.size.to_i32
        end

        def should_show_progress? : Bool
          @show_progress
        end

        def feed(iterator : Array(String), &process : String -> Array(String))
          words = Hash(String, UInt64).new(0_u64)
          iterator.each do |sequence|
            process.call(sequence).each do |word|
              words[word] += 1_u64
            end
          end
          @words = words
        end

        def do_train(word_counts : Hash(String, UInt64), model : BPE) : Array(AddedToken)
          word_to_id = Hash(String, UInt32).new
          id_to_word = [] of String
          max_token_length = @max_token_length || Int32::MAX

          # 1. Add all special tokens to the vocabulary
          @special_tokens.each do |token|
            content = token.content
            unless word_to_id.has_key?(content)
              id_to_word << content
              word_to_id[content] = (id_to_word.size - 1).to_u32
            end
          end

          # 2. Compute the initial alphabet
          alphabet = Hash(Char, UInt64).new(0_u64)
          word_counts.each do |word, count|
            word.each_char do |c|
              alphabet[c] += count
            end
          end
          @initial_alphabet.each do |c|
            alphabet[c] = UInt64::MAX
          end

          kept = alphabet.to_a
          if limit = @limit_alphabet
            to_remove = alphabet.size - limit
            if to_remove > 0
              kept.sort_by! { |(_, count)| count }
              kept = kept[to_remove..]
            end
          end
          kept.sort_by! { |(c, _)| c.ord }
          kept.each do |(c, _)|
            s = c.to_s
            unless word_to_id.has_key?(s)
              id_to_word << s
              word_to_id[s] = (id_to_word.size - 1).to_u32
            end
          end

          # 3. Tokenize words
          words = [] of Word
          counts = [] of UInt64
          word_counts.each do |word, count|
            current_word = Word.new
            counts << count

            word.each_char do |c|
              s = c.to_s
              if word_to_id.has_key?(s)
                current_word.add(word_to_id[s], 1_u32)
              end
            end

            words << current_word
          end

          # 4. Count pairs in words
          pair_counts = Hash(Pair, Int32).new(0)
          where_to_update = Hash(Pair, Set(Int32)).new { |h, k| h[k] = Set(Int32).new }
          words.each_with_index do |word, i|
            chars = word.get_chars
            chars.each_cons(2) do |(a, b)|
              pair = {a, b}
              pair_counts[pair] += counts[i].to_i32
              where_to_update[pair] << i.to_i32
            end
          end

          queue = Array(TrainerMerge).new
          where_to_update.drain do |pair, pos|
            count = pair_counts[pair]
            if count > 0
              queue << TrainerMerge.new(pair, count.to_u64, pos)
            end
          end
          queue.sort_by! { |m| {-(m.count).to_i64, m.pair[0], m.pair[1]} }

          # 5. Do merges
          merges = [] of {Pair, UInt32}
          loop do
            break if word_to_id.size >= @vocab_size

            top = queue.shift?
            break unless top

            if top.count != pair_counts[top.pair].to_u64
              top = TrainerMerge.new(top.pair, pair_counts[top.pair].to_u64, top.pos)
              insert_sorted(queue, top)
              next
            end

            break if top.count < 1 || @min_frequency > top.count

            part_a = id_to_word[top.pair[0]]
            part_b = id_to_word[top.pair[1]]
            if prefix = @continuing_subword_prefix
              if part_b.starts_with?(prefix)
                part_b = part_b[prefix.bytesize..]
              end
            end

            new_token = part_a + part_b
            new_token_id = word_to_id.fetch(new_token) { id_to_word.size.to_u32 }
            unless word_to_id.has_key?(new_token)
              id_to_word << new_token
              word_to_id[new_token] = new_token_id
            end
            merges << {top.pair, new_token_id}

            pos_list = top.pos.to_a.sort!
            all_changes = [] of Tuple(Pair, Int32, Int32)
            pos_list.each do |i|
              word = words[i]
              word_changes = word.merge(top.pair[0], top.pair[1], new_token_id, max_token_length.to_u32)
              word_changes.each do |(pair, change)|
                all_changes << {pair, change, i}
              end
            end

            all_changes.each do |(pair, change, iw)|
              count = change.to_i64 * counts[iw].to_i64
              pair_counts[pair] += count.to_i32
              if change > 0
                where_to_update[pair] << iw
              end
            end

            where_to_update.drain do |pair, pos|
              count = pair_counts[pair]
              if count > 0
                insert_sorted(queue, TrainerMerge.new(pair, count.to_u64, pos))
              end
            end
          end

          # 6. Transfer to model
          vocab = Vocab.new
          word_to_id.each do |_key, val|
            vocab[id_to_word[val]] = val
          end
          vocab_r = VocabR.new
          vocab.each do |key, val|
            vocab_r[val] = key
          end

          merge_map = MergeMap.new
          merges.each_with_index do |(pair, new_token_id), i|
            merge_map[pair] = {i.to_u32, new_token_id}
          end

          # Apply to model via setter
          model.vocab = vocab
          model.vocab_r = vocab_r
          model.merges = merge_map
          model.continuing_subword_prefix = @continuing_subword_prefix
          model.end_of_word_suffix = @end_of_word_suffix

          @special_tokens.dup
        end

        private def insert_sorted(queue : Array(TrainerMerge), item : TrainerMerge)
          index = queue.index { |m| m.count < item.count || (m.count == item.count && (m.pair[0] > item.pair[0] || (m.pair[0] == item.pair[0] && m.pair[1] > item.pair[1]))) }
          if index
            queue.insert(index, item)
          else
            queue << item
          end
        end

        def train(model : BPE) : Array(AddedToken)
          do_train(@words, model)
        end
      end

      class BpeTrainerBuilder
        def initialize
          @min_frequency = 0_u64
          @vocab_size = 30000
          @show_progress = false
          @special_tokens = [] of AddedToken
          @limit_alphabet = nil
          @initial_alphabet = Set(Char).new
          @continuing_subword_prefix = nil
          @end_of_word_suffix = nil
          @max_token_length = nil
        end

        def min_frequency(frequency : UInt64) : self
          @min_frequency = frequency
          self
        end

        def vocab_size(size : Int32) : self
          @vocab_size = size
          self
        end

        def show_progress(show : Bool) : self
          @show_progress = show
          self
        end

        def special_tokens(tokens : Array(AddedToken)) : self
          @special_tokens = tokens
          self
        end

        def limit_alphabet(limit : Int32) : self
          @limit_alphabet = limit
          self
        end

        def initial_alphabet(alphabet : Set(Char)) : self
          @initial_alphabet = alphabet
          self
        end

        def continuing_subword_prefix(prefix : String) : self
          @continuing_subword_prefix = prefix
          self
        end

        def end_of_word_suffix(suffix : String) : self
          @end_of_word_suffix = suffix
          self
        end

        def max_token_length(max_token_length : Int32) : self
          @max_token_length = max_token_length
          self
        end

        def build : BpeTrainer
          BpeTrainer.new(
            @min_frequency, @vocab_size, @show_progress,
            @special_tokens, @limit_alphabet, @initial_alphabet,
            @continuing_subword_prefix, @end_of_word_suffix,
            @max_token_length, Hash(String, UInt64).new,
          )
        end
      end
    end
  end
end
