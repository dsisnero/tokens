module Tokens
  module PreTokenizers
    class Sequence
      include Tokens::PreTokenizer

      getter pretokenizers : Array(Tokens::PreTokenizerWrapper)

      def initialize(pretokenizers : Array)
        @pretokenizers = pretokenizers.map do |pretokenizer|
          case pretokenizer
          when Tokens::PreTokenizerWrapper
            pretokenizer
          else
            Tokens::PreTokenizerWrapper.from(pretokenizer)
          end
        end
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        @pretokenizers.each(&.pre_tokenize(pretokenized))
      end

      def ==(other : self) : Bool
        @pretokenizers == other.pretokenizers
      end
    end
  end
end
