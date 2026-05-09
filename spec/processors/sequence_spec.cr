require "../spec_helper"

describe Tokens::PostProcessors::SequenceProcessor do
  it "process chain" do
    start = Tokens::Encoding.new(
      ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
      type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 1_u32}, {0_u32, 11_u32}, {11_u32, 18_u32}, {18_u32, 25_u32}, {25_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32
    )

    bytelevel = Tokens::PreTokenizers::ByteLevel.default.trim_offsets(true)
    wrapper = Tokens::PostProcessorWrapper.from(bytelevel)
    sequence = Tokens::PostProcessors::SequenceProcessor.new([wrapper])
    expected = Tokens::Encoding.new(
      ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
      type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      sequence_ranges: {0_u64 => 0_u64...5_u64}
    )

    bytelevel.process(start.copy, nil, false).should eq(expected)
    sequence.process(start.copy, nil, false).should eq(expected)

    pair_expected = Tokens::Encoding.new(
      ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
      type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32],
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ", "Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}, {0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      sequence_ranges: {0_u64 => 0_u64...5_u64, 1_u64 => 5_u64...10_u64}
    )

    bytelevel.process(start.copy, start.copy, false).should eq(pair_expected)
    sequence.process(start.copy, start.copy, false).should eq(pair_expected)
  end
end
