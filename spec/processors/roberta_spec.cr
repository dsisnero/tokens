require "../spec_helper"

describe Tokens::PostProcessors::RobertaProcessing do
  it "has default CLS and SEP tokens" do
    processor = Tokens::PostProcessors::RobertaProcessing.default
    processor.cls.should eq({"<s>", 0_u32})
    processor.sep.should eq({"</s>", 2_u32})
  end

  it "default settings" do
    processor = Tokens::PostProcessors::RobertaProcessing.default
    processor.trim_offsets?.should be_true
    processor.add_prefix_space?.should be_true
  end

  it "builder methods" do
    processor = Tokens::PostProcessors::RobertaProcessing.default
      .trim_offsets(false)
      .add_prefix_space(false)
    processor.trim_offsets?.should be_false
    processor.add_prefix_space?.should be_false
  end

  it "get_sep_copy and get_cls_copy return copies" do
    processor = Tokens::PostProcessors::RobertaProcessing.default
    sep = processor.get_sep_copy
    cls = processor.get_cls_copy
    sep.should eq({"</s>", 2_u32})
    cls.should eq({"<s>", 0_u32})
  end

  it "serde" do
    roberta = Tokens::PostProcessors::RobertaProcessing.default
    roberta_r = %({"type":"RobertaProcessing","sep":["</s>",2],"cls":["<s>",0],"trim_offsets":true,"add_prefix_space":true})
    roberta.to_json.should eq(roberta_r)
    Tokens::PostProcessors::RobertaProcessing.from_json(roberta_r).should eq(roberta)
  end

  it "roberta_processing" do
    processor = Tokens::PostProcessors::RobertaProcessing.default
    processor.added_tokens(false).should eq(2)
    processor.added_tokens(true).should eq(4)

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
        ids: [0_u32, 12_u32, 14_u32, 2_u32],
        type_ids: [0_u32, 0_u32, 0_u32, 0_u32],
        tokens: ["<s>", "Hello", "there", "</s>"],
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
        ids: [0_u32, 12_u32, 14_u32, 2_u32, 2_u32, 15_u32, 2_u32],
        type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32],
        tokens: ["<s>", "Hello", "there", "</s>", "</s>", "pair", "</s>"],
        words: [nil, nil, nil, nil, nil, nil, nil] of UInt32?,
        offsets: [{0_u32, 0_u32}, {0_u32, 5_u32}, {6_u32, 11_u32}, {0_u32, 0_u32}, {0_u32, 0_u32}, {0_u32, 4_u32}, {0_u32, 0_u32}],
        special_tokens_mask: [1_u32, 0_u32, 0_u32, 1_u32, 1_u32, 0_u32, 1_u32],
        attention_mask: [1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32],
        overflowing: [] of Tokens::Encoding,
        sequence_ranges: {0_u64 => 1_u64...3_u64, 1_u64 => 5_u64...6_u64}
      )
    )
    pair_encoding.token_to_sequence(2).should eq(0_u64)
    pair_encoding.token_to_sequence(3).should be_nil
    pair_encoding.token_to_sequence(4).should be_nil
    pair_encoding.token_to_sequence(5).should eq(1_u64)
    pair_encoding.token_to_sequence(6).should be_nil

    # No special tokens
    no_special = processor.process(encoding, pair, false)
    no_special.should eq(
      Tokens::Encoding.new(
        ids: [12_u32, 14_u32, 15_u32],
        type_ids: [0_u32, 0_u32, 0_u32],
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
