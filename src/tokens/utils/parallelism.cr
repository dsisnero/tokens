module Tokens
  module Parallelism
    ENV_VARIABLE = "TOKENIZERS_PARALLELISM"

    @@configured = false
    @@used = Atomic(Bool).new(false)
    @@parallelism = Atomic(UInt8).new(0)

    def self.reset!
      @@configured = false
      @@used.set(false)
      @@parallelism.set(0)
    end

    def self.get_parallelism : Bool
      case stored = @@parallelism.get
      when 1 then false
      when 2 then true
      else
        get_env_parallelism
      end
    end

    def self.set_parallelism(val : Bool) : Nil
      @@configured = true
      @@parallelism.set(val ? 2_u8 : 1_u8)
    end

    def self.has_parallelism_been_used : Bool
      @@used.get
    end

    def self.is_parallelism_configured : Bool
      @@configured
    end

    def self.mark_used!
      @@used.set(true)
    end

    private def self.get_env_parallelism : Bool
      {% if flag?(:preview_mt) %}
        if (env = ENV[ENV_VARIABLE]?) && !env.empty?
          env = env.downcase
          !env.in?("off", "false", "f", "no", "n", "0")
        else
          true
        end
      {% else %}
        false
      {% end %}
    end
  end
end
