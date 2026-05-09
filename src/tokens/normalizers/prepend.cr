module Tokens
  module Normalizers
    struct Prepend
      include Tokens::Normalizer

      property prepend : String

      def initialize(@prepend : String)
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.prepend(@prepend) unless normalized.empty?
      end
    end
  end
end
