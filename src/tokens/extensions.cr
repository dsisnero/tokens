class Hash(K, V)
  # Drains all key-value pairs from the hash, yielding each pair and then
  # clearing the hash while preserving its capacity.
  #
  # Equivalent to Rust's `HashMap::drain()` — empties the map but retains
  # the underlying storage so future insertions avoid an immediate rehash.
  def drain(& : Tuple(K, V) -> _) : Nil
    each do |key, value|
      yield({key, value})
    end
    clear
  end
end
