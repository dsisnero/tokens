module Tokens
  module Models
    module BPE
      class BpeCache
        @@next_cache_id : Atomic(UInt64) = Atomic(UInt64).new(0_u64)

        getter id : UInt64
        property capacity : Int32

        def initialize(@capacity : Int32)
          @id = @@next_cache_id.add(1_u64)
          @map = Hash(String, Word).new
        end

        def fresh : BpeCache
          BpeCache.new(@capacity)
        end

        def clear
          @id = @@next_cache_id.add(1_u64)
          @map.clear
        end

        def resize(new_capacity : Int32)
          @capacity = new_capacity
        end

        def get(key : String) : Word?
          @map[key]?
        end

        def set(key : String, word : Word)
          if @map.size < @capacity
            @map[key] = word
          end
        end
      end
    end
  end
end
