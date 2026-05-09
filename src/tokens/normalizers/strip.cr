module Tokens
  module Normalizers
    struct Strip
      include Tokens::Normalizer

      getter? strip_left : Bool
      getter? strip_right : Bool

      def initialize(@strip_left = true, @strip_right = true)
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        if @strip_left && @strip_right
          normalized.strip
        else
          normalized.lstrip if @strip_left
          normalized.rstrip if @strip_right
        end
      end
    end

    struct StripAccents
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.filter { |char| !char.mark? }
      end
    end
  end
end
