module Tokens
  def self.truncate_encodings(
    encoding : Encoding,
    pair_encoding : Encoding?,
    params : TruncationParams,
  ) : Tuple(Encoding, Encoding?)
    max_length = params.max_length.to_i32
    if max_length == 0
      encoding.truncate(0, params.stride.to_i32, params.direction)
      unless pair_encoding.nil?
        pair_encoding.not_nil!.truncate(0, params.stride.to_i32, params.direction)
      end
      return {encoding, pair_encoding}
    end

    total_length = encoding.length + (pair_encoding.try(&.length) || 0)
    if total_length <= max_length
      return {encoding, pair_encoding}
    end

    to_remove = total_length - max_length

    case params.strategy
    in TruncationStrategy::LongestFirst
      unless pair_encoding.nil?
        pe = pair_encoding.not_nil!
        n1 = encoding.length
        n2 = pe.length
        swapped = false

        if n1 > n2
          n1, n2 = n2, n1
          swapped = true
        end

        if n1 > max_length
          n2 = n1
        else
          n2 = Math.max(n1, max_length - n1)
        end

        if n1 + n2 > max_length
          n1 = max_length // 2
          n2 = n1 + max_length % 2
        end

        if swapped
          n1, n2 = n2, n1
        end

        encoding.truncate(n1, params.stride.to_i32, params.direction)
        pe.truncate(n2, params.stride.to_i32, params.direction)
        pair_encoding = pe
      else
        encoding.truncate(total_length - to_remove, params.stride.to_i32, params.direction)
      end
    in TruncationStrategy::OnlyFirst
      target_len = encoding.length
      if target_len > to_remove
        encoding.truncate(target_len - to_remove, params.stride.to_i32, params.direction)
      else
        raise "Truncation error: Sequence to truncate too short"
      end
    in TruncationStrategy::OnlySecond
      if pair_encoding.nil?
        raise "Truncation error: Second sequence not provided"
      end
      pe = pair_encoding.not_nil!
      target_len = pe.length
      if target_len > to_remove
        pe.truncate(target_len - to_remove, params.stride.to_i32, params.direction)
        pair_encoding = pe
      else
        raise "Truncation error: Sequence to truncate too short"
      end
    end

    {encoding, pair_encoding}
  end
end
