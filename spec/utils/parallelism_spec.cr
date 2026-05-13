require "../spec_helper"

describe "Parallelism" do
  it "test_maybe_parallel_iterator" do
    Tokens::Parallelism.reset!
    v = [1_u32, 2, 3, 4, 5, 6]

    v.sum(0_u32).should eq(21)

    v.map! { |x| x * 2 }
    v.sum(0_u32).should eq(42)

    Tokens::Parallelism.has_parallelism_been_used.should be_false
    Tokens::Parallelism.is_parallelism_configured.should be_false

    {% if flag?(:preview_mt) %}
      Tokens::Parallelism.get_parallelism.should eq(true)
    {% else %}
      Tokens::Parallelism.get_parallelism.should eq(false)
    {% end %}

    Tokens::Parallelism.set_parallelism(true)
    Tokens::Parallelism.is_parallelism_configured.should be_true

    Tokens::Parallelism.mark_used!
    Tokens::Parallelism.has_parallelism_been_used.should be_true
  end

  it "test_maybe_parallel_slice" do
    v = [1, 2, 3, 4, 5]

    chunks = v.each_slice(2).to_a
    chunks.should eq([[1, 2], [3, 4], [5]])
  end
end
