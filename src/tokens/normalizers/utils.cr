module Tokens
  module Normalizers
    class Sequence
      include Tokens::Normalizer

      getter normalizers : Array(Tokens::NormalizerWrapper)

      def initialize(normalizers : Array)
        @normalizers = normalizers.map do |normalizer|
          case normalizer
          when Tokens::NormalizerWrapper
            normalizer
          else
            Tokens::NormalizerWrapper.from(normalizer)
          end
        end
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        @normalizers.each(&.normalize(normalized))
      end
    end

    struct Lowercase
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.lowercase
      end
    end
  end
end
