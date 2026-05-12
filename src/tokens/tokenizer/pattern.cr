module Tokens
  module Pattern
    alias Match = Tuple(Tuple(UInt32, UInt32), Bool)

    abstract def find_matches(inside : String) : Array(Tuple(Tuple(UInt32, UInt32), Bool))

    def self.default_non_match(inside : String) : Array(Match)
      [{ {0_u32, inside.bytesize.to_u32}, false }]
    end

    def self.advance_after_zero_width_match(inside : String, offset : Int32) : Int32
      return inside.bytesize if offset >= inside.bytesize

      remaining = inside.byte_slice(offset, inside.bytesize - offset) || ""
      step = remaining.each_char.first?.try(&.bytesize) || 1
      offset + step
    end
  end

  struct Invert(P)
    include Pattern

    getter pattern : P

    def initialize(@pattern : P)
    end

    def find_matches(inside : String) : Array(Pattern::Match)
      @pattern.find_matches(inside).map do |(offsets, is_match)|
        {offsets, !is_match}
      end
    end
  end
end

struct Char
  include Tokens::Pattern

  def find_matches(inside : String) : Array(Tokens::Pattern::Match)
    ->(char : Char) { char == self }.find_matches(inside)
  end
end

class String
  include Tokens::Pattern

  def find_matches(inside : String) : Array(Tokens::Pattern::Match)
    return [{ {0_u32, inside.chars.size.to_u32}, false }] if empty?

    matches = [] of Tokens::Pattern::Match
    previous = 0
    token_length = bytesize

    while start = inside.byte_index(self, previous)
      matches << { {previous.to_u32, start.to_u32}, false } if previous != start

      stop = start + token_length
      matches << { {start.to_u32, stop.to_u32}, true }
      previous = stop
    end

    matches << { {previous.to_u32, inside.bytesize.to_u32}, false } if previous != inside.bytesize
    matches.empty? ? Tokens::Pattern.default_non_match(inside) : matches
  end
end

class Regex
  include Tokens::Pattern

  def find_matches(inside : String) : Array(Tokens::Pattern::Match)
    return Tokens::Pattern.default_non_match(inside) if inside.empty?

    matches = [] of Tokens::Pattern::Match
    previous = 0

    while match = self.match(inside, previous)
      start = match.byte_begin(0)
      stop = match.byte_end(0)

      matches << { {previous.to_u32, start.to_u32}, false } if previous != start
      matches << { {start.to_u32, stop.to_u32}, true }

      previous = stop
      previous = Tokens::Pattern.advance_after_zero_width_match(inside, previous) if start == stop
    end

    matches << { {previous.to_u32, inside.bytesize.to_u32}, false } if previous != inside.bytesize
    matches.empty? ? Tokens::Pattern.default_non_match(inside) : matches
  end
end

struct Proc(*T, R)
  include Tokens::Pattern

  def find_matches(inside : String) : Array(Tokens::Pattern::Match)
    return Tokens::Pattern.default_non_match(inside) if inside.empty?

    matches = [] of Tokens::Pattern::Match
    previous = 0
    last_seen = 0
    offset = 0

    inside.each_char do |char|
      start = offset
      stop = start + char.bytesize
      last_seen = stop

      if call(char)
        matches << { {previous.to_u32, start.to_u32}, false } if previous < start
        matches << { {start.to_u32, stop.to_u32}, true }
        previous = stop
      end

      offset = stop
    end

    matches << { {previous.to_u32, last_seen.to_u32}, false } if last_seen > previous
    matches.empty? ? Tokens::Pattern.default_non_match(inside) : matches
  end
end

module Tokens
  class SysRegex
    include Pattern

    getter regex : Regex

    def initialize(source : String)
      @regex = Regex.new(source)
    end

    def find_iter(inside : String) : Array(Tuple(UInt32, UInt32))
      return [] of Tuple(UInt32, UInt32) if inside.empty?

      offsets = [] of Tuple(UInt32, UInt32)
      previous = 0

      inside.scan(@regex) do |match|
        start = match.byte_begin(0)
        stop = match.byte_end(0)

        # Only include matches at or after the current position
        if start >= previous
          offsets << {start.to_u32, stop.to_u32}
          previous = stop
          previous = Pattern.advance_after_zero_width_match(inside, previous) if start == stop
        end
      end

      offsets
    end

    def find_matches(inside : String) : Array(Pattern::Match)
      return Pattern.default_non_match(inside) if inside.empty?

      matches = [] of Pattern::Match
      previous = 0

      find_iter(inside).each do |(start_u32, stop_u32)|
        start = start_u32.to_i
        stop = stop_u32.to_i

        matches << { {previous.to_u32, start.to_u32}, false } if previous != start
        matches << { {start.to_u32, stop.to_u32}, true }
        previous = stop
      end

      matches << { {previous.to_u32, inside.bytesize.to_u32}, false } if previous != inside.bytesize
      matches.empty? ? Pattern.default_non_match(inside) : matches
    end
  end
end
