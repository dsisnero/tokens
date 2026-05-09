module Tokens
  module PreTokenizers
    struct UnicodeScripts
      include Tokens::PreTokenizer

      def self.default : self
        new
      end

      def self.fixed_script(char : Char) : UnicodeScriptsData::Script
        raw_script = UnicodeScriptsData.get_script(char)
        if char.ord == 0x30FC
          UnicodeScriptsData::Script::Han
        elsif char == ' '
          UnicodeScriptsData::Script::Any
        else
          case raw_script
          when UnicodeScriptsData::Script::Hiragana, UnicodeScriptsData::Script::Katakana
            UnicodeScriptsData::Script::Han
          else
            raw_script
          end
        end
      end

      def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
        pretokenized.split do |_, normalized|
          last_script : UnicodeScriptsData::Script? = nil
          offset = 0
          ranges = [] of Int32

          normalized.get.each_char do |char|
            script = self.class.fixed_script(char)
            if script != UnicodeScriptsData::Script::Any &&
               last_script != UnicodeScriptsData::Script::Any &&
               last_script != script
              ranges << offset
            end
            offset += char.bytesize
            last_script = script unless script == UnicodeScriptsData::Script::Any
          end

          ranges << normalized.get.bytesize

          splits = [] of Tokens::Split
          0.upto(ranges.size - 2) do |index|
            slice = normalized.slice(Tokens::Range::Normalized.new(ranges[index]...ranges[index + 1])) ||
                    raise "NormalizedString bad split"
            splits << Tokens::Split.new(slice)
          end
          splits
        end
      end
    end
  end
end
