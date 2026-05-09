require "../spec_helper"

describe Tokens::PostProcessors::Piece do
  it "piece serde" do
    seq_0 = Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::A, 0_u32)
    seq_0_s = %({"Sequence":{"id":"A","type_id":0}})
    seq_0.to_json.should eq(seq_0_s)
    Tokens::PostProcessors::Piece.from_json(seq_0_s).should eq(seq_0)

    seq_1 = Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::B, 1_u32)
    seq_1_s = %({"Sequence":{"id":"B","type_id":1}})
    seq_1.to_json.should eq(seq_1_s)
    Tokens::PostProcessors::Piece.from_json(seq_1_s).should eq(seq_1)

    spe = Tokens::PostProcessors::Piece.special_token("[CLS]", 0_u32)
    spe_s = %({"SpecialToken":{"id":"[CLS]","type_id":0}})
    spe.to_json.should eq(spe_s)
    Tokens::PostProcessors::Piece.from_json(spe_s).should eq(spe)
  end

  it "piece parsing" do
    Tokens::PostProcessors::Piece.parse("$").should eq(
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::A, 0_u32)
    )
    Tokens::PostProcessors::Piece.parse("$B").should eq(
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::B, 0_u32)
    )
    Tokens::PostProcessors::Piece.parse("$1").should eq(
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::A, 1_u32)
    )
    Tokens::PostProcessors::Piece.parse("$B:2").should eq(
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::B, 2_u32)
    )
    Tokens::PostProcessors::Piece.parse("$:1").should eq(
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::A, 1_u32)
    )
    expect_raises(Exception, /Cannot build Piece/) { Tokens::PostProcessors::Piece.parse("$C:1") }
    expect_raises(Exception, /Cannot build Piece/) { Tokens::PostProcessors::Piece.parse("$A:") }
  end
end

describe Tokens::PostProcessors::TemplateSpecialToken do
  it "special token serde" do
    simple = Tokens::PostProcessors::TemplateSpecialToken.new("[CLS]", [0_u32], ["[CLS]"])
    simple_s = %({"id":"[CLS]","ids":[0],"tokens":["[CLS]"]})
    simple.to_json.should eq(simple_s)
    Tokens::PostProcessors::TemplateSpecialToken.from_json(simple_s).should eq(simple)

    complete = Tokens::PostProcessors::TemplateSpecialToken.new("[2FR]", [1_u32, 2_u32, 3_u32], ["convert", "to", "FR"])
    complete_s = %({"id":"[2FR]","ids":[1,2,3],"tokens":["convert","to","FR"]})
    complete.to_json.should eq(complete_s)
    Tokens::PostProcessors::TemplateSpecialToken.from_json(complete_s).should eq(complete)

    # Mismatched lengths should raise
    expect_raises(Exception, /ids and tokens must be of the same length/) do
      Tokens::PostProcessors::TemplateSpecialToken.new("[2FR]", [1_u32, 2_u32], ["convert", "to", "FR"])
    end
    expect_raises(Exception, /ids and tokens must be of the same length/) do
      Tokens::PostProcessors::TemplateSpecialToken.new("[2FR]", [1_u32, 2_u32, 3_u32], ["convert", "FR"])
    end
  end
end

describe Tokens::PostProcessors::ProcTemplate do
  it "template serde" do
    template = Tokens::PostProcessors::ProcTemplate.new([
      Tokens::PostProcessors::Piece.sequence(Tokens::PostProcessors::ProcessorSequence::A, 0_u32),
      Tokens::PostProcessors::Piece.special_token("[CLS]", 0_u32),
    ])
    template_s = %([{"Sequence":{"id":"A","type_id":0}},{"SpecialToken":{"id":"[CLS]","type_id":0}}])
    template.to_json.should eq(template_s)
    Tokens::PostProcessors::ProcTemplate.from_json(template_s).should eq(template)
  end
end

describe Tokens::PostProcessors::TokensMap do
  it "tokens serde" do
    tokens = Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", 1_u32},
      {"[SEP]", 0_u32},
    ])
    tokens_s = %({"[CLS]":{"id":"[CLS]","ids":[1],"tokens":["[CLS]"]},"[SEP]":{"id":"[SEP]","ids":[0],"tokens":["[SEP]"]}})
    tokens.to_json.should eq(tokens_s)
    Tokens::PostProcessors::TokensMap.from_json(tokens_s).should eq(tokens)
  end
end

private def get_bert_template : Tokens::PostProcessors::TemplateProcessing
  Tokens::PostProcessors::TemplateProcessing.build(
    single: Tokens::PostProcessors::ProcTemplate.parse("[CLS] $0 [SEP]"),
    pair: Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0 $B:1 [SEP]:1"),
    special_tokens: Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", 1_u32},
      {"[SEP]", 0_u32},
    ])
  )
end

describe Tokens::PostProcessors::TemplateProcessing do
  it "template processing serde" do
    template = get_bert_template
    template_s = "{\"type\":\"TemplateProcessing\",\"single\":[{\"SpecialToken\":{\"id\":\"[CLS]\",\"type_id\":0}},{\"Sequence\":{\"id\":\"A\",\"type_id\":0}},{\"SpecialToken\":{\"id\":\"[SEP]\",\"type_id\":0}}],\"pair\":[{\"SpecialToken\":{\"id\":\"[CLS]\",\"type_id\":0}},{\"Sequence\":{\"id\":\"A\",\"type_id\":0}},{\"SpecialToken\":{\"id\":\"[SEP]\",\"type_id\":0}},{\"Sequence\":{\"id\":\"B\",\"type_id\":1}},{\"SpecialToken\":{\"id\":\"[SEP]\",\"type_id\":1}}],\"special_tokens\":{\"[CLS]\":{\"id\":\"[CLS]\",\"ids\":[1],\"tokens\":[\"[CLS]\"]},\"[SEP]\":{\"id\":\"[SEP]\",\"ids\":[0],\"tokens\":[\"[SEP]\"]}}}"
    template.to_json.should eq(template_s)
    Tokens::PostProcessors::TemplateProcessing.from_json(template_s).should eq(template)
  end

  it "missing special tokens" do
    expect_raises(Exception, /Missing SpecialToken.*/) do
      Tokens::PostProcessors::TemplateProcessing.build(
        single: Tokens::PostProcessors::ProcTemplate.parse("[CLS] $0 [SEP]"),
        pair: Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A:0 [SEP] $B:1 [SEP]"),
        special_tokens: Tokens::PostProcessors::TokensMap.new
      )
    end
  end

  it "template processing" do
    processor = get_bert_template
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
        ids: [1_u32, 12_u32, 14_u32, 0_u32],
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
        ids: [1_u32, 12_u32, 14_u32, 0_u32, 15_u32, 0_u32],
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
  end

  it "pair must use both sequences" do
    result = expect_raises(Exception, /must use both sequences/) do
      Tokens::PostProcessors::TemplateProcessing.build(
        single: Tokens::PostProcessors::ProcTemplate.parse("$0"),
        pair: Tokens::PostProcessors::ProcTemplate.parse("$0 $1"),
        special_tokens: Tokens::PostProcessors::TokensMap.new
      )
    end
  end

  it "expect wrong error message" do
    result = expect_raises(Exception) do
      Tokens::PostProcessors::TemplateProcessing.build(
        single: Tokens::PostProcessors::ProcTemplate.parse("$0"),
        pair: Tokens::PostProcessors::ProcTemplate.parse("$0 $1"),
        special_tokens: Tokens::PostProcessors::TokensMap.new
      )
    end
    result.message.should_not eq("Expect the left side error message to be different from the right side!")
  end
end
