module Tokens
  module Normalizers
    class Precompiled
      include Tokens::Normalizer

      getter transformations : Hash(String, String)

      def initialize(@transformations = {} of String => String)
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        return if @transformations.empty?

        replacements = [] of Tuple(Char, Int32)
        modified = false

        normalized.get.each_grapheme do |grapheme|
          grapheme_string = grapheme.to_s
          if grapheme_string.bytesize < 6
            if replacement = @transformations[grapheme_string]?
              modified = true
              self.class.replace(replacements, grapheme_string, replacement)
              next
            end
          end

          grapheme_string.each_char do |char|
            part = char.to_s
            if replacement = @transformations[part]?
              modified = true
              self.class.replace(replacements, part, replacement)
            else
              replacements << {char, 0}
            end
          end
        end

        normalized.transform(replacements, 0) if modified
      end

      def self.replace(transformations : Array(Tuple(Char, Int32)), old_part : String, new_part : String)
        old_count = old_part.chars.size
        new_count = new_part.chars.size
        diff = new_count - old_count

        new_part.each_char { |char| transformations << {char, 0} }

        case diff <=> 0
        when 1
          diff.times do |index|
            transformations[-(index + 1)] = {transformations[-(index + 1)][0], 1}
          end
        when -1
          if last = transformations.last?
            transformations[-1] = {last[0], last[1] + diff}
          end
        end
      end
    end
  end
end
