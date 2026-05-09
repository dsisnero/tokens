require "../spec_helper"

describe Tokens::PostProcessors::BertProcessing do
  it "has default CLS and SEP tokens" do
    processor = Tokens::PostProcessors::BertProcessing.default
    processor.cls.should eq({"[CLS]", 101_u32})
    processor.sep.should eq({"[SEP]", 102_u32})
  end

  it "get_sep_copy and get_cls_copy return copies" do
    processor = Tokens::PostProcessors::BertProcessing.default
    sep = processor.get_sep_copy
    cls = processor.get_cls_copy
    sep.should eq({"[SEP]", 102_u32})
    cls.should eq({"[CLS]", 101_u32})
  end

  it "serde" do
    bert = Tokens::PostProcessors::BertProcessing.default
    bert_r = %({"type":"BertProcessing","sep":["[SEP]",102],"cls":["[CLS]",101]})
    bert.to_json.should eq(bert_r)
    Tokens::PostProcessors::BertProcessing.from_json(bert_r).should eq(bert)
  end

  it "bert_processing" do
    processor = Tokens::PostProcessors::BertProcessing.default
    processor.added_tokens(false).should eq(2)
    processor.added_tokens(true).should eq(3)

    encoding = Tokens::Encoding.from_tokens(
      [
        Tokens::Token.new(12_u32, "Hello", {0_u32, 5_u32}),
        Tokens::Token.new(14_u32, "there", {6_u32, 11_u32}),
      ],
      0_u32
    )
    pair = Tokens::Encoding.from_tokens(
      [Tokens::Token.new(15_u32, "pair", {0_u32, 4_u32})],
      0_u32
    )

    single_encoding = processor.process(encoding, nil, true)
    single_encoding.should eq(
      Tokens::Encoding.new(
        ids: [101_u32, 12_u32, 14_u32, 102_u32],
        type_ids: [0_u32, 0_u32, 0_u32, 0_u32],
        tokens: ["[CLS]", "Hello", "there", "[SEP]"],
        words: [nil, nil, nil, nil] of UInt32?,
        offsets: [{0_u32, 0_u32}, {0_u32, 5_u32}, {6_u32, 11_u32}, {0_u32, 0_u32}],
        special_tokens_mask: [1_u32, 0_u32, 0_u32, 1_u32],
        attention_mask: [1_u32, 1_u32, 1_u32, 1_u32],
        overflowing: [] of Tokens::Encoding,
        sequence_ranges: {0_u64 => 1_u64...3_u64}
      )
    )
    single_encoding.token_to_sequence(2).should eq(0_u64)
    single_encoding.token_to_sequence(3).should be_nil

    pair_encoding = processor.process(encoding, pair, true)
    pair_encoding.should eq(
      Tokens::Encoding.new(
        ids: [101_u32, 12_u32, 14_u32, 102_u32, 15_u32, 102_u32],
        type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 1_u32, 1_u32],
        tokens: ["[CLS]", "Hello", "there", "[SEP]", "pair", "[SEP]"],
        words: [nil, nil, nil, nil, nil, nil] of UInt32?,
        offsets: [{0_u32, 0_u32}, {0_u32, 5_u32}, {6_u32, 11_u32}, {0_u32, 0_u32}, {0_u32, 4_u32}, {0_u32, 0_u32}],
        special_tokens_mask: [1_u32, 0_u32, 0_u32, 1_u32, 0_u32, 1_u32],
        attention_mask: [1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32],
        overflowing: [] of Tokens::Encoding,
        sequence_ranges: {0_u64 => 1_u64...3_u64, 1_u64 => 4_u64...5_u64}
      )
    )
    pair_encoding.token_to_sequence(2).should eq(0_u64)
    pair_encoding.token_to_sequence(3).should be_nil
    pair_encoding.token_to_sequence(4).should eq(1_u64)
    pair_encoding.token_to_sequence(5).should be_nil

    # No special tokens
    no_special = processor.process(encoding, pair, false)
    no_special.should eq(
      Tokens::Encoding.new(
        ids: [12_u32, 14_u32, 15_u32],
        type_ids: [0_u32, 0_u32, 1_u32],
        tokens: ["Hello", "there", "pair"],
        words: [nil, nil, nil] of UInt32?,
        offsets: [{0_u32, 5_u32}, {6_u32, 11_u32}, {0_u32, 4_u32}],
        special_tokens_mask: [0_u32, 0_u32, 0_u32],
        attention_mask: [1_u32, 1_u32, 1_u32],
        overflowing: [] of Tokens::Encoding,
        sequence_ranges: {0_u64 => 0_u64...2_u64, 1_u64 => 2_u64...3_u64}
      )
    )
    no_special.token_to_sequence(0).should eq(0_u64)
    no_special.token_to_sequence(1).should eq(0_u64)
    no_special.token_to_sequence(2).should eq(1_u64)
  end
end
