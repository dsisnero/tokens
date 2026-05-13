require "../spec_helper"

describe Tokens::TokenizerImpl do
  it "serializes and deserializes round-trip" do
    tok_json = %({"version":"1.0","truncation":null,"padding":null,"added_tokens":[{"id":0,"content":"[SPECIAL_0]","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true},{"id":1,"content":"[SPECIAL_1]","single_word":false,"lstrip":false,"rstrip":false,"normalized":true,"special":false},{"id":2,"content":"[SPECIAL_2]","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true}],"normalizer":null,"pre_tokenizer":null,"post_processor":null,"decoder":null,"model":{"type":"BPE","dropout":null,"unk_token":null,"continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":false,"vocab":{},"merges":[]}})

    tokenizer = Tokens::TokenizerImpl.from_json(tok_json)
    tokenizer.should be_a(Tokens::TokenizerImpl)

    # Round-trip: serialize and deserialize again
    serialized = tokenizer.to_json
    restored = Tokens::TokenizerImpl.from_json(serialized)
    restored.should be_a(Tokens::TokenizerImpl)

    # Verify added tokens survived round-trip
    restored.get_added_vocabulary.len.should eq(3)
  end

  it "round-trips non-null truncation and padding settings" do
    model = Tokens::Models::WordLevel.build({"hello" => 0_u32, "[UNK]" => 1_u32}, "[UNK]")
    tokenizer = Tokens::TokenizerImpl.new(model)
      .with_truncation(Tokens::TruncationParams.new(
        max_length: 32_u64,
        strategy: Tokens::TruncationStrategy::OnlySecond,
        stride: 4_u64,
        direction: Tokens::TruncationDirection::Left,
      ))
      .with_padding(Tokens::PaddingParams.new(
        strategy: Tokens::PaddingStrategy::Fixed,
        direction: Tokens::PaddingDirection::Left,
        pad_to_multiple_of: 8_u64,
        pad_id: 9_u32,
        pad_type_id: 2_u32,
        pad_token: "<pad>",
        fixed_size: 64_u64,
      ))

    restored = Tokens::TokenizerImpl.from_json(tokenizer.to_json)

    truncation = restored.get_truncation.not_nil!
    truncation.max_length.should eq(32_u64)
    truncation.strategy.should eq(Tokens::TruncationStrategy::OnlySecond)
    truncation.stride.should eq(4_u64)
    truncation.direction.should eq(Tokens::TruncationDirection::Left)

    padding = restored.get_padding.not_nil!
    padding.strategy.should eq(Tokens::PaddingStrategy::Fixed)
    padding.direction.should eq(Tokens::PaddingDirection::Left)
    padding.pad_to_multiple_of.should eq(8_u64)
    padding.pad_id.should eq(9_u32)
    padding.pad_type_id.should eq(2_u32)
    padding.pad_token.should eq("<pad>")
    padding.fixed_size.should eq(64_u64)
  end

  it "rejects unknown versions" do
    invalid = %({"version":"0.0","model":{"type":"BPE","vocab":{},"merges":[]},"added_tokens":[]})

    expect_raises(Exception, /Unknown tokenizer version/) do
      Tokens::TokenizerImpl.from_json(invalid)
    end
  end

  it "rejects missing model" do
    invalid = %({"version":"1.0","added_tokens":[]})

    expect_raises(Exception, /Missing model/) do
      Tokens::TokenizerImpl.from_json(invalid)
    end
  end
end
