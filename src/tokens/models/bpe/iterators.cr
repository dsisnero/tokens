struct FirstLastIterator(T)
  include Iterator(Tuple(Bool, Bool, T))

  @iter : Iterator(T)
  @first : Bool
  @peek : T | Iterator::Stop

  def initialize(iter : Iterator(T))
    @iter = iter
    @first = true
    @peek = iter.next
  end

  def next
    peek = @peek
    return stop if peek.is_a?(Iterator::Stop)

    is_first = @first
    @first = false
    @peek = @iter.next
    is_last = @peek.is_a?(Iterator::Stop)
    {is_first, is_last, peek}
  end
end

class Array(T)
  def with_first_and_last : FirstLastIterator(T)
    FirstLastIterator(T).new(self.each)
  end
end
