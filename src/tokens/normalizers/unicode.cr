module Tokens
  module Normalizers
    struct NFD
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.nfd
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "NFD"
        end
      end
    end

    struct NFKD
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.nfkd
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "NFKD"
        end
      end
    end

    struct NFC
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.nfc
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "NFC"
        end
      end
    end

    struct NFKC
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized.nfkc
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "NFKC"
        end
      end
    end

    struct Nmt
      include Tokens::Normalizer

      def normalize(normalized : Tokens::NormalizedString) : Nil
        normalized
          .filter { |char| !remove_nmt_control?(char.ord) }
          .map { |char| nmt_space(char.ord) || char }
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "Nmt"
        end
      end

      private def remove_nmt_control?(codepoint : Int32) : Bool
        case codepoint
        when 0x0001..0x0008, 0x000B, 0x000E..0x001F, 0x007F, 0x008F, 0x009F
          true
        else
          false
        end
      end

      private def nmt_space(codepoint : Int32) : Char?
        case codepoint
        when 0x0009, 0x000A, 0x000C, 0x000D, 0x1680, 0x2028, 0x2029, 0x2581, 0xFEFF, 0xFFFD
          ' '
        when 0x200B..0x200F
          ' '
        else
          nil
        end
      end
    end
  end
end
