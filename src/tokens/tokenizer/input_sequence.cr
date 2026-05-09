module Tokens
  struct InputSequence
    getter raw : String?
    getter pretokenized : Array(String)?

    def initialize(@raw : String? = nil, @pretokenized : Array(String)? = nil)
    end

    def self.new(s : String)
      new(raw: s)
    end

    def self.new(arr : Array(String))
      new(pretokenized: arr)
    end

    def raw?
      @raw
    end

    def pretokenized?
      @pretokenized
    end
  end

  struct EncodeInput
    getter single : InputSequence?
    getter dual : Tuple(InputSequence, InputSequence)?

    def initialize(single : InputSequence? = nil, dual : Tuple(InputSequence, InputSequence)? = nil)
      @single = single
      @dual = dual
    end

    def self.new(s : String)
      new(single: InputSequence.new(s))
    end

    def self.new(pair : Tuple(String, String))
      new(dual: {InputSequence.new(pair[0]), InputSequence.new(pair[1])})
    end
  end
end
