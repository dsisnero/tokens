module Tokens
  module Models
    module BPE
      class Error < TokenizerError
      end

      class BadVocabulary < Error
        def initialize
          super("Bad vocabulary json file")
        end
      end

      class BadMerges < Error
        getter line : Int32

        def initialize(@line : Int32)
          super("Invalid merges line #{line}")
        end
      end

      class MergeTokenOutOfVocabulary < Error
        getter token : String

        def initialize(@token : String)
          super("Token `#{token}` out of vocabulary")
        end
      end

      class UnkTokenOutOfVocabulary < Error
        getter token : String

        def initialize(@token : String)
          super("Unk token `#{token}` not found in the vocabulary")
        end
      end

      class InvalidDropout < Error
        def initialize
          super("Dropout should be between 0 and 1, inclusive")
        end
      end
    end
  end
end
