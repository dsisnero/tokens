# Progress bar utility ported from upstream tokenizers/src/utils/progress.rs
# Crystal has no indicatif equivalent; provides a simple no-op progress bar.

module Tokens
  # Controls how progress is reported during training
  enum ProgressFormat
    Indicatif # Interactive terminal progress bars (no-op in Crystal)
    JsonLines # Machine-readable JSON to stderr
    Silent    # No progress output
  end

  struct ProgressStyle
    getter template_string : String

    def initialize(@template_string = "")
    end

    def self.default_bar : self
      new("[{elapsed_precise}] {msg:<30!} {wide_bar} {pos:<9!}/{len:>9!}")
    end

    def template(template : String) : self
      self.class.new(template)
    end
  end

  class ProgressBar
    getter length : UInt64
    getter position : UInt64

    def initialize(@length : UInt64 = 0_u64)
      @position = 0_u64
      @style = ProgressStyle.default_bar
      @message = ""
      @format = ProgressFormat::Silent
    end

    def self.new(len : UInt64) : self
      new(len)
    end

    def set_message(msg : String) : Nil
      @message = msg
    end

    def set_length(len : UInt64) : Nil
      @length = len
    end

    def set_style(style : ProgressStyle) : Nil
      @style = style
    end

    def inc(value : UInt64 = 1_u64) : Nil
      @position += value
    end

    def reset : Nil
      @position = 0_u64
    end

    def finish : Nil
      @position = @length
    end

    def set_progress_format(format : ProgressFormat) : Nil
      @format = format
    end
  end
end
