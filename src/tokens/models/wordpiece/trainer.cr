module Tokens
  module Models
    class WordPieceTrainer
      include ::Tokens::Trainer(WordPiece)

      @bpe_trainer : BPE::BpeTrainer

      def initialize(
        min_frequency : UInt64 = 0_u64,
        vocab_size : Int32 = 30000,
        show_progress : Bool = true,
        special_tokens : Array(AddedToken) = [] of AddedToken,
      )
        @bpe_trainer = BPE::BpeTrainer.new(
          min_frequency: min_frequency,
          vocab_size: vocab_size,
          show_progress: show_progress,
          special_tokens: special_tokens,
          limit_alphabet: nil,
          initial_alphabet: Set(Char).new,
          continuing_subword_prefix: "##",
          end_of_word_suffix: nil,
          max_token_length: nil,
          words: {} of String => UInt64,
        )
      end

      def self.default : self
        new
      end

      delegate min_frequency, to: @bpe_trainer
      delegate vocab_size, to: @bpe_trainer
      delegate special_tokens, to: @bpe_trainer

      def min_frequency=(freq : UInt64)
        @bpe_trainer.min_frequency = freq
      end

      def vocab_size=(size : Int32)
        @bpe_trainer.vocab_size = size
      end

      def show_progress=(show : Bool)
        @bpe_trainer.show_progress = show
      end

      def special_tokens=(tokens : Array(AddedToken))
        @bpe_trainer.special_tokens = tokens
      end

      def should_show_progress? : Bool
        @bpe_trainer.should_show_progress?
      end

      def train(model : WordPiece) : Array(AddedToken)
        bpe = BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[]}))
        special_tokens = @bpe_trainer.do_train(@bpe_trainer.words, bpe)
        new_wp = WordPiece.from_bpe(bpe)
        model.copy_vocab_from(new_wp)
        special_tokens
      end

      def feed(strings : Array(String), &process : String -> Array(String))
        @bpe_trainer.feed(strings, &process)
      end
    end
  end
end
