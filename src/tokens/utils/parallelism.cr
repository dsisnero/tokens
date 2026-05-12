module Tokens
  module Parallelism
    ENV_VARIABLE = "TOKENIZERS_PARALLELISM"

    @@configured = false
    @@used = false

    def self.get_parallelism : Bool
      true
    end

    def self.set_parallelism(val : Bool) : Nil
      @@configured = true
    end

    def self.has_parallelism_been_used : Bool
      @@used
    end

    def self.is_parallelism_configured : Bool
      @@configured
    end

    def self.mark_used!
      @@used = true
    end
  end
end
