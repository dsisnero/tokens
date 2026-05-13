module Tokens
  module Models
    module BPE
      private struct Symbol
        property c : UInt32
        property prev : Int32
        property next : Int32
        property len : UInt32

        def initialize(@c : UInt32, @prev : Int32, @next : Int32, @len : UInt32)
        end

        def merge_with(other : Symbol, new_c : UInt32)
          @c = new_c
          @len += other.len
          @next = other.next
        end
      end

      # Internal merge entry for the priority queue.
      # QuaternaryHeap in Rust is a min-heap where Ord cmp reverses rank then pos.
      # We implement our own to match exact behavior.
      private struct Merge
        property pos : Int32
        property rank : UInt32
        property new_id : UInt32

        def initialize(@pos : Int32, @rank : UInt32, @new_id : UInt32)
        end
      end

      # Min-heap ordered by (rank, pos) — matches Rust's QuaternaryHeap behavior.
      # QuaternaryHeap is a min-heap in Rust with reversed Ord impl on Merge,
      # which means pop returns the lowest rank, then lowest pos.
      private class MergeHeap
        def initialize(capacity : Int32 = 0)
          @items = [] of Merge
        end

        def size
          @items.size
        end

        def extend(items : Array(Merge))
          items.each { |item| push(item) }
        end

        def push(item : Merge)
          @items << item
          sift_up(@items.size - 1)
        end

        def pop : Merge?
          return nil if @items.empty?
          result = @items[0]
          last = @items.pop
          if @items.size > 0
            @items[0] = last
            sift_down(0)
          end
          result
        end

        def size
          @items.size
        end

        private def sift_up(idx : Int32)
          while idx > 0
            parent = (idx - 1) // 2
            break if order(@items[parent], @items[idx]) <= 0
            @items.swap(idx, parent)
            idx = parent
          end
        end

        private def sift_down(idx : Int32)
          loop do
            smallest = idx
            left = 2 * idx + 1
            right = 2 * idx + 2

            if left < @items.size && order(@items[left], @items[smallest]) < 0
              smallest = left
            end
            if right < @items.size && order(@items[right], @items[smallest]) < 0
              smallest = right
            end
            break if smallest == idx
            @items.swap(idx, smallest)
            idx = smallest
          end
        end

        # Matches Rust Ord: lower rank first, then lower pos first
        private def order(a : Merge, b : Merge) : Int32
          if a.rank != b.rank
            a.rank <=> b.rank
          else
            a.pos <=> b.pos
          end
        end
      end

      class Word
        def initialize
          @symbols = [] of Symbol
        end

        def self.with_capacity(capacity : Int32) : Word
          w = Word.new
          w.symbols = Array(Symbol).new(capacity)
          w
        end

        # Rust: add updates last.next to len, then pushes new symbol.
        # prev = len-1 (or -1 if empty), next = -1
        def add(c : UInt32, byte_len : UInt32)
          len = @symbols.size.to_i32
          if len > 0
            last = @symbols.last
            @symbols[-1] = Symbol.new(last.c, last.prev, len, last.len)
          end
          prev_val = len > 0 ? len - 1 : -1_i32
          @symbols << Symbol.new(c, prev_val, -1_i32, byte_len)
        end

        # Rust merge: linear scan, replaces pair (c1,c2) with replacement in-place.
        def merge(c1 : UInt32, c2 : UInt32, replacement : UInt32, max_length : UInt32) : Array({Pair, Int32})
          changes = [] of {Pair, Int32}
          i = 0
          loop do
            break if i >= @symbols.size

            if @symbols[i].c == c1 && i + 1 < @symbols.size && @symbols[i + 1].c == c2
              first = @symbols[i]
              second = @symbols[i + 1]

              new_s = Symbol.new(replacement, first.prev, second.next, first.len + second.len)

              if i > 0
                changes << { {@symbols[i - 1].c, first.c}, -1_i32 }
                if @symbols[i - 1].len + new_s.len < max_length
                  changes << { {@symbols[i - 1].c, replacement}, 1_i32 }
                end
              end

              @symbols.insert(i, new_s)
              @symbols.delete_at(i + 1)
              @symbols.delete_at(i + 1)

              if i < @symbols.size - 1
                changes << { {second.c, @symbols[i + 1].c}, -1_i32 }
                if @symbols[i + 1].len + new_s.len < max_length
                  changes << { {replacement, @symbols[i + 1].c}, 1_i32 }
                end
              end
            end

            i += 1
          end
          changes
        end

        # ameba:disable Metrics/CyclomaticComplexity
        def merge_all(merges : Hash(Pair, {UInt32, UInt32}), dropout : Float32?)
          queue = MergeHeap.new(@symbols.size.to_i32)
          skip = [] of Merge

          @symbols.each_cons(2).with_index do |window, idx|
            pair = {window[0].c, window[1].c}
            if m = merges[pair]?
              queue.push(Merge.new(idx.to_i32, m[0], m[1]))
            end
          end

          max_iter = @symbols.size * @symbols.size * 2
          iter = 0
          while item = queue.pop
            iter += 1
            if iter > max_iter
              raise "Infinite loop in merge_all: queue.size=#{queue.size}, item=#{item.inspect}, symbols=#{@symbols.inspect}"
            end
            if dropout
              if rand < dropout
                skip << item
                next
              else
                skip.each { |skip_item| queue.push(skip_item) }
                skip.clear
              end
            end

            if @symbols[item.pos].len == 0
              next
            end

            if @symbols[item.pos].next == -1
              next
            end

            next_pos = @symbols[item.pos].next
            right = @symbols[next_pos]

            target_new_pair = {@symbols[item.pos].c, right.c}
            if entry = merges[target_new_pair]?
              if entry[1] != item.new_id
                next
              end
            else
              next
            end

            merged = @symbols[item.pos]
            merged.merge_with(right, item.new_id)
            @symbols[item.pos] = merged
            @symbols[next_pos] = Symbol.new(right.c, right.prev, right.next, 0_u32)

            if right.next > -1 && right.next < @symbols.size
              sym = @symbols[right.next]
              @symbols[right.next] = Symbol.new(sym.c, item.pos, sym.next, sym.len)
            end

            current = @symbols[item.pos]
            if current.prev >= 0
              prev_sym = @symbols[current.prev]
              new_pair = {prev_sym.c, current.c}
              if m = merges[new_pair]?
                queue.push(Merge.new(current.prev, m[0], m[1]))
              end
            end

            nxt = current.next
            if nxt >= 0 && nxt < @symbols.size
              next_sym = @symbols[nxt]
              new_pair = {current.c, next_sym.c}
              if m = merges[new_pair]?
                queue.push(Merge.new(item.pos, m[0], m[1]))
              end
            end
          end

          @symbols.reject! { |symbol| symbol.len == 0 }
        end

        def get_chars : Array(UInt32)
          @symbols.map(&.c)
        end

        def each_symbol_with_offset(& : UInt32, UInt32, UInt32 ->) : Nil
          offset = 0_u32
          @symbols.each do |symbol|
            next_offset = offset + symbol.len
            yield symbol.c, offset, next_offset
            offset = next_offset
          end
        end

        def chars_iter : Iterator(UInt32)
          @symbols.map(&.c).to_a.each
        end

        def offsets_iter : Iterator(Tuple(UInt32, UInt32))
          pos = 0_u32
          @symbols.map do |sym|
            new_pos = pos + sym.len
            offset = {pos, new_pos}
            pos = new_pos
            offset
          end.each
        end

        def size
          @symbols.size
        end

        protected property symbols : Array(Symbol)
      end
    end
  end
end
