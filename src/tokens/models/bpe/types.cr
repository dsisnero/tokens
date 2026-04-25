module Tokens
  module Models
    module BPE
      alias Pair = Tuple(UInt32, UInt32)
      alias Vocab = Hash(String, UInt32)
      alias VocabR = Hash(UInt32, String)
      alias MergeMap = Hash(Pair, Tuple(UInt32, UInt32))
      alias Merges = Array(Tuple(String, String))

      DEFAULT_CACHE_CAPACITY = 10_000
      MAX_CACHE_LENGTH       =    256

      record AddedToken,
        content : String,
        single_word : Bool = false,
        lstrip : Bool = false,
        rstrip : Bool = false,
        normalized : Bool = true,
        special : Bool = false
    end
  end
end
