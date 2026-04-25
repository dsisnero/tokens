module Tokens
  record Token, id : UInt32, value : String, offsets : Tuple(UInt32, UInt32)
end
