require "../spec_helper"

module Tokens
  describe Encoding do
    it "merge_with growing offsets" do
      a = Encoding.new(
        ids: [1_u32],
        type_ids: [0_u32],
        tokens: ["Hello "],
        words: [0_u32],
        offsets: [{0_u32, 6_u32}],
        special_tokens_mask: [0_u32],
        attention_mask: [1_u32]
      )
      b = Encoding.new(
        ids: [2_u32],
        type_ids: [1_u32],
        tokens: ["World!"],
        words: [0_u32],
        offsets: [{0_u32, 6_u32}],
        special_tokens_mask: [0_u32],
        attention_mask: [1_u32]
      )
      a.merge_with(b, true)

      a.ids.should eq([1_u32, 2_u32])
      a.type_ids.should eq([0_u32, 1_u32])
      a.tokens.should eq(["Hello ", "World!"])
      a.words.should eq([0_u32, 0_u32])
      a.offsets.should eq([{0_u32, 6_u32}, {6_u32, 12_u32}])
      a.special_tokens_mask.should eq([0_u32, 0_u32])
      a.attention_mask.should eq([1_u32, 1_u32])
    end

    it "truncate right" do
      a = Encoding.new(
        ids: [1_u32, 2_u32, 3_u32],
        type_ids: [0_u32, 0_u32, 0_u32],
        tokens: ["Hello", "World", "!"],
        words: [0_u32, 1_u32, 2_u32],
        offsets: [{0_u32, 5_u32}, {6_u32, 11_u32}, {11_u32, 12_u32}],
        special_tokens_mask: [0_u32, 0_u32, 0_u32],
        attention_mask: [1_u32, 1_u32, 1_u32]
      )
      a.truncate(2, 0, TruncationDirection::Right)

      a.ids.should eq([1_u32, 2_u32])
      a.tokens.should eq(["Hello", "World"])
      a.overflowing.size.should eq(1)
      a.overflowing[0].ids.should eq([3_u32])
      a.overflowing[0].tokens.should eq(["!"])
    end

    it "truncate left" do
      a = Encoding.new(
        ids: [1_u32, 2_u32, 3_u32],
        type_ids: [0_u32, 0_u32, 0_u32],
        tokens: ["Hello", "World", "!"],
        words: [0_u32, 1_u32, 2_u32],
        offsets: [{0_u32, 5_u32}, {6_u32, 11_u32}, {11_u32, 12_u32}],
        special_tokens_mask: [0_u32, 0_u32, 0_u32],
        attention_mask: [1_u32, 1_u32, 1_u32]
      )
      a.truncate(2, 0, TruncationDirection::Left)

      a.ids.should eq([2_u32, 3_u32])
      a.tokens.should eq(["World", "!"])
      a.overflowing.size.should eq(1)
      a.overflowing[0].ids.should eq([1_u32])
      a.overflowing[0].tokens.should eq(["Hello"])
    end

    it "truncate to empty" do
      a = Encoding.new(
        ids: [1_u32, 2_u32, 3_u32],
        type_ids: [0_u32, 0_u32, 0_u32],
        tokens: ["Hello", "World", "!"],
        words: [0_u32, 1_u32, 2_u32],
        offsets: [{0_u32, 5_u32}, {6_u32, 11_u32}, {11_u32, 12_u32}],
        special_tokens_mask: [0_u32, 0_u32, 0_u32],
        attention_mask: [1_u32, 1_u32, 1_u32]
      )
      a.truncate(0, 0, TruncationDirection::Right)

      a.ids.should be_empty
      a.overflowing.size.should eq(1)
      a.overflowing[0].ids.should eq([1_u32, 2_u32, 3_u32])
    end

    it "truncate with stride" do
      enc = Encoding.new(
        ids: [1_u32, 2_u32, 3_u32, 4_u32, 5_u32],
        type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
        tokens: ["42", "is", "the", "answer", "!"],
        words: [0_u32, 1_u32, 2_u32, 3_u32, 4_u32],
        offsets: [{0_u32, 2_u32}, {2_u32, 4_u32}, {4_u32, 7_u32}, {7_u32, 13_u32}, {13_u32, 14_u32}],
        special_tokens_mask: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
        attention_mask: [1_u32, 1_u32, 1_u32, 1_u32, 1_u32]
      )
      enc.truncate(4, 2, TruncationDirection::Right)

      enc.ids.should eq([1_u32, 2_u32, 3_u32, 4_u32])
      enc.tokens.should eq(["42", "is", "the", "answer"])
      enc.overflowing.size.should eq(1)
      enc.overflowing[0].ids.should eq([3_u32, 4_u32, 5_u32])
      enc.overflowing[0].tokens.should eq(["the", "answer", "!"])
    end

    it "mappings" do
      encoding = Encoding.new(
        ids: Array(UInt32).new(11, 0_u32),
        tokens: (["He", "llo", "won", "der", "ful", "friend", "!"] +
                 ["How", "are", "you", "?"]),
        offsets: [
          {0_u32, 2_u32},
          {2_u32, 5_u32},
          {7_u32, 10_u32},
          {10_u32, 13_u32},
          {13_u32, 16_u32},
          {17_u32, 23_u32},
          {23_u32, 24_u32},
          {0_u32, 3_u32},
          {4_u32, 7_u32},
          {8_u32, 11_u32},
          {11_u32, 12_u32},
        ],
        words: [
          0_u32, 0_u32, 1_u32, 1_u32, 1_u32, 2_u32, 3_u32,
          0_u32, 1_u32, 2_u32, 3_u32,
        ],
        type_ids: Array(UInt32).new(11, 0_u32),
        attention_mask: Array(UInt32).new(11, 1_u32),
        sequence_ranges: {0_u64 => 0_u64...7_u64, 1_u64 => 7_u64...11_u64}
      )

      encoding.word_to_tokens(0_u32, 0).should eq({0, 2})
      encoding.word_to_tokens(1_u32, 0).should eq({2, 5})
      encoding.word_to_tokens(2_u32, 0).should eq({5, 6})
      encoding.word_to_tokens(3_u32, 0).should eq({6, 7})
      encoding.word_to_tokens(0_u32, 1).should eq({7, 8})
      encoding.word_to_tokens(1_u32, 1).should eq({8, 9})
      encoding.word_to_tokens(2_u32, 1).should eq({9, 10})
      encoding.word_to_tokens(3_u32, 1).should eq({10, 11})

      encoding.word_to_chars(0_u32, 0).should eq({0_u32, 5_u32})
      encoding.word_to_chars(1_u32, 0).should eq({7_u32, 16_u32})
      encoding.word_to_chars(0_u32, 1).should eq({0_u32, 3_u32})
      encoding.word_to_chars(1_u32, 1).should eq({4_u32, 7_u32})

      encoding.token_to_chars(0).should eq({0_u64, {0_u32, 2_u32}})
      encoding.token_to_chars(1).should eq({0_u64, {2_u32, 5_u32}})
      encoding.token_to_chars(7).should eq({1_u64, {0_u32, 3_u32}})
      encoding.token_to_chars(9).should eq({1_u64, {8_u32, 11_u32}})

      encoding.token_to_word(1).should eq({0_u64, 0_u32})
      encoding.token_to_word(2).should eq({0_u64, 1_u32})
      encoding.token_to_word(7).should eq({1_u64, 0_u32})
      encoding.token_to_word(9).should eq({1_u64, 2_u32})
      encoding.token_to_word(11).should be_nil

      encoding.char_to_token(3_u32, 0).should eq(1)
      encoding.char_to_token(8_u32, 0).should eq(2)
      encoding.char_to_token(16_u32, 0).should be_nil
      encoding.char_to_token(23_u32, 0).should eq(6)
      encoding.char_to_token(2_u32, 1).should eq(7)
      encoding.char_to_token(9_u32, 1).should eq(9)

      encoding.char_to_word(3_u32, 0).should eq(0_u32)
      encoding.char_to_word(8_u32, 0).should eq(1_u32)
      encoding.char_to_word(16_u32, 0).should be_nil
      encoding.char_to_word(23_u32, 0).should eq(3_u32)
      encoding.char_to_word(2_u32, 1).should eq(0_u32)
      encoding.char_to_word(9_u32, 1).should eq(2_u32)
    end

    it "padding" do
      a = Encoding.new(
        ids: [1_u32],
        type_ids: [0_u32],
        tokens: ["Hello "],
        words: [0_u32],
        offsets: [{0_u32, 6_u32}],
        special_tokens_mask: [0_u32],
        attention_mask: [1_u32],
        sequence_ranges: {0_u64 => 0_u64...1_u64}
      )
      a.pad(2, 99_u32, 0_u32, "[PAD]", PaddingDirection::Left)
      a.sequence_ranges.should eq({0_u64 => 1_u64...2_u64})
    end
  end
end
