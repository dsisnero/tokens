module Tokens
  module Models
    module Unigram
      # A generic Trie for prefix search.
      # Label must be hashable and comparable.
      class Trie(Label)
        @root : Node(Label)

        def initialize
          @root = Node(Label).new
        end

        def push(element : Array(Label)) : Nil
          node = @root
          element.each do |label|
            unless node.children.has_key?(label)
              node.children[label] = Node(Label).new
            end
            node = node.children[label]
          end
          node.is_leaf = true
        end

        # Performs common prefix search.
        # Given an iterator of labels, yields each prefix that forms a complete
        # entry in the trie.
        def common_prefix_search(iterator : Iterator(Label)) : Array(Array(Label))
          results = [] of Array(Label)
          node = @root
          prefix = [] of Label

          iterator.each do |label|
            prefix << label
            child = node.children[label]?
            break unless child
            node = child
            results << prefix.dup if node.is_leaf
          end

          results
        end
      end

      class Node(Label)
        property is_leaf : Bool
        property children : Hash(Label, Node(Label))

        def initialize
          @is_leaf = false
          @children = {} of Label => Node(Label)
        end
      end
    end
  end
end
