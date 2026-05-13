module Tokens
  module Models
    module BPE
      class BpeBuilder
        def initialize
          @vocab = Vocab.new
          @merges = [] of Tuple(String, String)
          @cache_capacity = DEFAULT_CACHE_CAPACITY
          @dropout = nil
          @unk_token = nil
          @continuing_subword_prefix = nil
          @end_of_word_suffix = nil
          @fuse_unk = false
          @byte_fallback = false
          @ignore_merges = false
          @files = nil
        end

        def files(vocab : String, merges : String) : self
          @files = {vocab, merges}
          self
        end

        def vocab_and_merges(vocab : Vocab, merges : Merges) : self
          @vocab = vocab
          @merges = merges
          self
        end

        def cache_capacity(capacity : Int32) : self
          @cache_capacity = capacity
          self
        end

        def dropout(p : Float32) : self
          @dropout = p
          self
        end

        def unk_token(token : String) : self
          @unk_token = token
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

        def fuse_unk(value : Bool) : self
          @fuse_unk = value
          self
        end

        def byte_fallback(value : Bool) : self
          @byte_fallback = value
          self
        end

        def ignore_merges(value : Bool) : self
          @ignore_merges = value
          self
        end

        def build : BPE
          if d = @dropout
            if d < 0.0_f32 || d > 1.0_f32
              raise InvalidDropout.new
            end
          end

          if files = @files
            vocab_path, merges_path = files
            @vocab, @merges = BPE.read_file(vocab_path, merges_path)
          end

          vocab = @vocab
          vocab_r = BPE.build_reverse_vocab(vocab)

          cache = @cache_capacity > 0 ? BpeCache.new(@cache_capacity) : nil

          prefix_len = if p = @continuing_subword_prefix
                         p.bytesize
                       else
                         0
                       end

          merge_map = BPE.build_merge_map(vocab, @merges, prefix_len)

          BPE.new(
            vocab, vocab_r, merge_map,
            cache, @dropout, @unk_token,
            @continuing_subword_prefix, @end_of_word_suffix,
            @fuse_unk, @byte_fallback, @ignore_merges,
          )
        end
      end
    end
  end
end
