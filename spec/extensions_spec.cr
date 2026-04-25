require "./spec_helper"

describe "Hash#drain" do
  it "yields each key-value pair and clears the hash" do
    h = {"a" => 1, "b" => 2, "c" => 3}
    drained = [] of {String, Int32}
    h.drain do |k, v|
      drained << {k, v}
    end
    drained.sort!.should eq([{"a", 1}, {"b", 2}, {"c", 3}])
    h.should be_empty
  end

  it "preserves capacity after draining" do
    h = Hash(Int32, Int32).new(initial_capacity: 16)
    (0...10).each { |i| h[i] = i }
    h.drain { |k, v| }
    h.size.should eq(0)
  end

  it "yields nothing on empty hash" do
    h = Hash(Int32, Int32).new
    count = 0
    h.drain { |k, v| count += 1 }
    count.should eq(0)
  end
end
