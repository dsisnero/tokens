# Iterator utilities ported from upstream tokenizers/src/utils/iter.rs
# LinesWithEnding: reads lines preserving \n and \r endings (unlike File.read_lines)
# ResultShunt: not needed in Crystal — exceptions handle error propagation natively

module Tokens
  module IterUtils
    # Read all lines from a file path, preserving line endings (\n, \r).
    # This matches the upstream `lines_with_ending()` behavior used in train_from_files.
    def self.read_lines_with_ending(path : String) : Array(String)
      File.open(path) do |file|
        lines = [] of String
        while line = file.gets(chomp: false)
          lines << line
        end
        lines
      end
    end
  end
end
