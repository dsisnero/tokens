require "../spec_helper"

def get_empty_encoding
  Tokens::Encoding.new
end

def get_short_encoding
  Tokens::Encoding.new(
    ids: [1_u32, 2_u32],
    type_ids: [0_u32, 0_u32],
    tokens: ["a", "b"],
    words: [0_u32, 1_u32],
    offsets: [{0_u32, 1_u32}, {1_u32, 2_u32}],
    special_tokens_mask: [0_u32, 0_u32],
    attention_mask: [1_u32, 1_u32]
  )
end

def get_medium_encoding
  Tokens::Encoding.new(
    ids: [3_u32, 4_u32, 5_u32, 6_u32],
    type_ids: [0_u32, 0_u32, 0_u32, 0_u32],
    tokens: ["d", "e", "f", "g"],
    words: [0_u32, 1_u32, 2_u32, 3_u32],
    offsets: [{0_u32, 1_u32}, {1_u32, 2_u32}, {2_u32, 3_u32}, {3_u32, 4_u32}],
    special_tokens_mask: [0_u32, 0_u32, 0_u32, 0_u32],
    attention_mask: [1_u32, 1_u32, 1_u32, 1_u32]
  )
end

def get_long_encoding
  Tokens::Encoding.new(
    ids: [7_u32, 8_u32, 9_u32, 10_u32, 11_u32, 12_u32, 13_u32, 14_u32],
    type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
    tokens: ["h", "i", "j", "k", "l", "m", "n", "o"],
    words: [0_u32, 1_u32, 2_u32, 3_u32, 4_u32, 5_u32, 6_u32, 7_u32],
    offsets: [{0_u32, 1_u32}, {1_u32, 2_u32}, {2_u32, 3_u32}, {3_u32, 4_u32}, {4_u32, 5_u32}, {5_u32, 6_u32}, {6_u32, 7_u32}, {6_u32, 8_u32}],
    special_tokens_mask: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
    attention_mask: [1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32]
  )
end

def truncate_and_assert(e1 : Tokens::Encoding, e2 : Tokens::Encoding, params : Tokens::TruncationParams, n1 : Int32, n2 : Int32)
  result, pe = Tokens.truncate_encodings(e1, e2, params)
  result.length.should eq(n1)
  pe.should_not be_nil
  pe.not_nil!.length.should eq(n2)
end

module Tokens
  describe "truncation" do
    it "longest first" do
      params = TruncationParams.new(
        max_length: 7_u64,
        strategy: TruncationStrategy::LongestFirst,
        stride: 0_u64,
        direction: TruncationDirection::Right
      )

      truncate_and_assert(get_empty_encoding, get_empty_encoding, params, 0, 0)
      truncate_and_assert(get_empty_encoding, get_short_encoding, params, 0, 2)
      truncate_and_assert(get_empty_encoding, get_medium_encoding, params, 0, 4)
      truncate_and_assert(get_empty_encoding, get_long_encoding, params, 0, 7)
      truncate_and_assert(get_short_encoding, get_empty_encoding, params, 2, 0)
      truncate_and_assert(get_short_encoding, get_short_encoding, params, 2, 2)
      truncate_and_assert(get_short_encoding, get_medium_encoding, params, 2, 4)
      truncate_and_assert(get_short_encoding, get_long_encoding, params, 2, 5)
      truncate_and_assert(get_medium_encoding, get_empty_encoding, params, 4, 0)
      truncate_and_assert(get_medium_encoding, get_short_encoding, params, 4, 2)
      truncate_and_assert(get_medium_encoding, get_medium_encoding, params, 3, 4)
      truncate_and_assert(get_medium_encoding, get_long_encoding, params, 3, 4)
      truncate_and_assert(get_long_encoding, get_empty_encoding, params, 7, 0)
      truncate_and_assert(get_long_encoding, get_short_encoding, params, 5, 2)
      truncate_and_assert(get_long_encoding, get_medium_encoding, params, 4, 3)
      truncate_and_assert(get_long_encoding, get_long_encoding, params, 3, 4)
    end

    it "truncate empty" do
      params = TruncationParams.new(
        max_length: 0_u64,
        strategy: TruncationStrategy::LongestFirst,
        stride: 0_u64,
        direction: TruncationDirection::Right
      )

      truncate_and_assert(get_empty_encoding, get_short_encoding, params, 0, 0)
      truncate_and_assert(get_medium_encoding, get_medium_encoding, params, 0, 0)
      truncate_and_assert(get_long_encoding, get_long_encoding, params, 0, 0)
    end

    it "deserializes missing direction to right" do
      params = TruncationParams.from_json(%({"max_length":256,"strategy":"LongestFirst","stride":0}))

      params.direction.should eq(TruncationDirection::Right)
    end
  end
end
