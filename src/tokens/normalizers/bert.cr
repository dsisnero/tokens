module Tokens
  module Normalizers
    struct BertNormalizer
      include Tokens::Normalizer

      getter? clean_text : Bool
      getter? handle_chinese_chars : Bool
      property strip_accents : Bool?
      getter? lowercase : Bool

      def initialize(
        @clean_text = true,
        @handle_chinese_chars = true,
        @strip_accents : Bool? = nil,
        @lowercase = true,
      )
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        do_clean_text(normalized) if @clean_text
        do_handle_chinese_chars(normalized) if @handle_chinese_chars

        should_strip_accents = @strip_accents.nil? ? @lowercase : @strip_accents.as(Bool)
        do_strip_accents(normalized) if should_strip_accents
        normalized.lowercase if @lowercase
      end

      private def do_clean_text(normalized : Tokens::NormalizedString)
        normalized
          .filter { |char| !(char.ord == 0 || char.ord == 0xFFFD || bert_control?(char)) }
          .map { |char| bert_whitespace?(char) ? ' ' : char }
      end

      private def do_handle_chinese_chars(normalized : Tokens::NormalizedString)
        transformations = [] of Tuple(Char, Int32)
        normalized.get.each_char do |char|
          if chinese_char?(char)
            transformations << {' ', 0}
            transformations << {char, 1}
            transformations << {' ', 1}
          else
            transformations << {char, 0}
          end
        end
        normalized.transform(transformations, 0)
      end

      private def do_strip_accents(normalized : Tokens::NormalizedString)
        normalized.nfd.filter { |char| !char.mark? }
      end

      private def bert_whitespace?(char : Char) : Bool
        case char
        when '\t', '\n', '\r'
          true
        else
          char.whitespace?
        end
      end

      private def bert_control?(char : Char) : Bool
        case char
        when '\t', '\n', '\r'
          false
        else
          char.control?
        end
      end

      private def chinese_char?(char : Char) : Bool
        case char.ord
        when 0x4E00..0x9FFF,
             0x3400..0x4DBF,
             0x20000..0x2A6DF,
             0x2A700..0x2B73F,
             0x2B740..0x2B81F,
             0x2B920..0x2CEAF,
             0xF900..0xFAFF,
             0x2F800..0x2FA1F
          true
        else
          false
        end
      end
    end
  end
end
