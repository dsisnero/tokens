require "./token"

module Tokens
  class TokenizerError < Exception
  end

  module Model
    abstract def tokenize(sequence : String) : Array(Token)
    abstract def token_to_id(token : String) : UInt32?
    abstract def id_to_token(id : UInt32) : String?
    abstract def vocab : Hash(String, UInt32)
    abstract def vocab_size : UInt32
    abstract def save(folder : String, name : String? = nil) : Array(String)
    abstract def trainer
  end
end
