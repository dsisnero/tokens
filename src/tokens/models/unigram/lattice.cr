module Tokens
  module Models
    module Unigram
      # A node in the Viterbi lattice. Each node represents a token candidate
      # covering positions [pos, pos+length) in the sentence.
      class LatticeNode
        property id : Int32          # Vocab ID
        property node_id : Int32     # Global lattice node identifier
        property pos : Int32         # Start position in bytes
        property length : Int32      # Length in bytes
        property prev : LatticeNode? # Backpointer for Viterbi
        property backtrace_score : Float64
        property score : Float64

        def initialize(@id : Int32, @node_id : Int32, @pos : Int32, @length : Int32, @score : Float64)
          @prev = nil
          @backtrace_score = 0.0
        end

        def ==(other : self) : Bool
          @id == other.id
        end
      end

      # Viterbi lattice for finding optimal tokenization or sampling from
      # all possible encodings of a given sentence.
      class Lattice
        getter sentence : String
        getter len : Int32
        getter nodes : Array(LatticeNode)
        getter begin_nodes : Array(Array(LatticeNode))
        getter end_nodes : Array(Array(LatticeNode))
        getter bos_id : Int32
        getter eos_id : Int32

        def initialize(@sentence : String, bos_id : Int32, eos_id : Int32)
          @len = sentence.bytesize
          @bos_id = bos_id
          @eos_id = eos_id
          k_reserved = 16

          @nodes = Array(LatticeNode).new(k_reserved)
          @begin_nodes = Array.new(@len + 1) { Array(LatticeNode).new(k_reserved) }
          @end_nodes = Array.new(@len + 1) { Array(LatticeNode).new(k_reserved) }

          bos = LatticeNode.new(bos_id, 0, 0, 0, 0.0)
          eos = LatticeNode.new(eos_id, 1, @len, 0, 0.0)

          @begin_nodes[@len] << eos
          @end_nodes[0] << bos
          @nodes << bos << eos
        end

        def insert(pos : Int32, length : Int32, score : Float64, id : Int32) : Nil
          node_id = @nodes.size
          node = LatticeNode.new(id, node_id, pos, length, score)
          @begin_nodes[pos] << node
          @end_nodes[pos + length] << node
          @nodes << node
        end

        def piece(node : LatticeNode) : String
          @sentence.byte_slice(node.pos, node.length) || ""
        end

        def tokens : Array(String)
          viterbi.map { |n| piece(n) }
        end

        # Viterbi algorithm: find the best-scoring path through the lattice.
        def viterbi : Array(LatticeNode)
          pos = 0
          while pos <= @len
            if @begin_nodes[pos].empty?
              return [] of LatticeNode
            end

            @begin_nodes[pos].each do |rnode|
              rnode.prev = nil
              best_score = 0.0
              best_node = nil

              @end_nodes[pos].each do |lnode|
                score = lnode.backtrace_score + rnode.score
                if best_node.nil? || score > best_score
                  best_node = lnode
                  best_score = score
                end
              end

              if bnode = best_node
                rnode.prev = bnode
                rnode.backtrace_score = best_score
              else
                return [] of LatticeNode
              end
            end

            # Advance to next character boundary
            if pos < @len
              remaining = @sentence.byte_slice(pos, @len - pos) || ""
              char_bytes = remaining.each_char.first?.try(&.bytesize) || 1
              pos += char_bytes
            else
              break
            end
          end

          # Backtrack from EOS
          if @begin_nodes[@len].empty?
            return [] of LatticeNode
          end

          root = @begin_nodes[@len][0]
          prev = root.prev
          return [] of LatticeNode unless prev

          results = [] of LatticeNode
          node = prev
          while node.prev
            results << node
            node = node.prev.not_nil!
          end
          results.reverse
        end

        # N-best search: find the top n tokenization paths.
        def nbest(n : Int32) : Array(Array(LatticeNode))
          case n
          when 0
            [] of Array(LatticeNode)
          when 1
            best = viterbi
            best.empty? ? [] of Array(LatticeNode) : [best]
          else
            # First, fill backtrace scores with viterbi
            viterbi

            agenda = Array(Hypothesis).new
            hypotheses = [] of Array(LatticeNode)

            eos = @begin_nodes[@len][0]
            score = eos.score
            agenda << Hypothesis.new(eos, nil, score, score)
            agenda.sort_by! { |h| -h.fx } # Max-heap: largest fx first

            while !agenda.empty?
              top = agenda.shift

              node = top.node_ref
              if node.id == @end_nodes[0][0].id # BOS
                path = [] of LatticeNode
                curr = top.next
                while curr && curr.next
                  path << curr.node_ref
                  curr = curr.next
                end
                hypotheses << path
                if hypotheses.size == n
                  return hypotheses
                end
              else
                @end_nodes[node.pos].each do |lnode|
                  fx = lnode.backtrace_score + top.gx
                  gx = lnode.score + top.gx
                  hyp = Hypothesis.new(lnode, top, fx, gx)
                  # Insert keeping sorted by fx (descending, max-heap)
                  idx = agenda.bsearch_index { |h| h.fx <= hyp.fx } || agenda.size
                  agenda.insert(idx, hyp)
                end

                # Shrink agenda if too large
                k_max = 100000
                k_min = 512
                if agenda.size > k_max
                  new_size = {k_min, n * 10}.min
                  agenda = agenda[0...new_size]
                end
              end
            end
            hypotheses
          end
        end

        def nbest_tokens(n : Int32) : Array(Array(String))
          nbest(n).map { |nodes| nodes.map { |node| piece(node) } }
        end

        def surface(n : Int32) : String
          char_indices = [] of Int32
          byte_offset = 0
          @sentence.each_char do |char|
            char_indices << byte_offset
            byte_offset += char.bytesize
          end
          if n < char_indices.size
            @sentence.byte_slice(char_indices[n], @len - char_indices[n]) || ""
          else
            ""
          end
        end
      end

      # Hypothesis for N-best search. Ordered by fx (ascending).
      class Hypothesis
        getter node_ref : LatticeNode
        getter next : Hypothesis?
        getter fx : Float64
        getter gx : Float64

        def initialize(@node_ref : LatticeNode, @next : Hypothesis?, @fx : Float64, @gx : Float64)
        end
      end

      # log(exp(x) + exp(y)), numerically stable
      def self.log_sum_exp(x : Float64, y : Float64, init_mode : Bool) : Float64
        if init_mode
          y
        else
          vmin, vmax = if x > y
                         {y, x}
                       else
                         {x, y}
                       end
          k = 50.0_f64
          if vmax > vmin + k
            vmax
          else
            vmax + Math.log(Math.exp(vmin - vmax) + 1.0)
          end
        end
      end
    end
  end
end
