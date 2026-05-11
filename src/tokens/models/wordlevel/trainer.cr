module Tokens
  module Models
    class WordLevelTrainer
      include ::Tokens::Trainer(Tokens::Models::WordLevel)

      property min_frequency : UInt64
      property vocab_size : Int32
      property show_progress : Bool
      property special_tokens : Array(AddedToken)
      property words : Hash(String, UInt64)

      def initialize(
        @min_frequency = 0_u64,
        @vocab_size = 30000,
        @show_progress = true,
        @special_tokens = [] of AddedToken,
        @words = {} of String => UInt64,
      )
      end

      def self.default : self
        new
      end

      def should_show_progress? : Bool
        @show_progress
      end

      def train(model : WordLevel) : Array(AddedToken)
        do_train(@words, model)
      end

      def feed(strings : Array(String), &process : String -> Array(String))
        strings.each do |sequence|
          words = process.call(sequence)
          words.each do |word|
            @words[word] = (@words[word]? || 0_u64) + 1
          end
        end
      end

      def do_train(word_counts : Hash(String, UInt64), model : WordLevel) : Array(AddedToken)
        # Sort by frequency descending, then alphabetically
        sorted = word_counts.to_a.sort do |(word_a, count_a), (word_b, count_b)|
          cmp = count_b <=> count_a
          cmp == 0 ? word_a <=> word_b : cmp
        end

        # Build vocab: special tokens first, then frequent words
        vocab = {} of String => UInt32
        next_id = 0_u32

        @special_tokens.each do |token|
          vocab[token.content] = next_id
          next_id += 1
        end

        sorted.each do |(word, count)|
          break if vocab.size >= @vocab_size
          next if count < @min_frequency
          unless vocab.has_key?(word)
            vocab[word] = next_id
            next_id += 1
          end
        end

        # Build reverse mapping
        vocab_r = {} of UInt32 => String
        vocab.each { |key, val| vocab_r[val] = key }

        # Transfer to model
        model.vocab_set(vocab)
        model.vocab_r_set(vocab_r)

        @special_tokens
      end
    end
  end
end
