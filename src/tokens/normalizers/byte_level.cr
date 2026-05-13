require "set"

module Tokens
  module Normalizers
    struct ByteLevel
      include Tokens::Normalizer

      @@bytes_char : Hash(UInt8, Char)?

      def initialize
      end

      def self.alphabet : Set(Char)
        alphabet = Set(Char).new
        bytes_char.each_value { |char| alphabet << char }
        alphabet
      end

      def normalize(normalized : Tokens::NormalizedString) : Nil
        return if normalized.empty?

        raw = normalized.get
        transformations = Array({Char, Int32}).new(raw.bytesize)
        raw.each_byte do |byte|
          change = (byte & 0xC0) == 0x80 ? 1 : 0
          transformations << {self.class.bytes_char[byte], change}
        end
        normalized.transform(transformations, 0)
      end

      def self.bytes_char : Hash(UInt8, Char)
        @@bytes_char ||= begin
          bs = [] of UInt8
          bs.concat((UInt8.new('!'.ord))..(UInt8.new('~'.ord)))
          bs.concat((0xA1_u8)..(0xAC_u8))
          bs.concat((0xAE_u8)..(0xFF_u8))

          cs = bs.map(&.to_u32)
          n = 0_u32

          (0_u8..0xFF_u8).each do |byte|
            next if bs.includes?(byte)

            bs << byte
            cs << (1_u32 << 8) + n
            n += 1
          end

          map = {} of UInt8 => Char
          bs.zip(cs) do |byte, codepoint|
            map[byte] = codepoint.to_i.chr
          end
          map
        end
      end
    end
  end
end
