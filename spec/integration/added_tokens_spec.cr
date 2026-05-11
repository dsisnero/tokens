require "../spec_helper"

describe "Added tokens integration tests" do
  it "add_special_tokens and add_tokens" do
    # Use an empty BPE model (matching upstream get_empty)
    empty_bpe = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[]}))
    tokenizer = Tokens::TokenizerImpl.new(empty_bpe)

    result = tokenizer.add_special_tokens([
      Tokens::AddedToken.from("<cls>", true),
      Tokens::AddedToken.from("<sep>", true),
    ])
    result.should eq(2_u64)
    tokenizer.token_to_id("<cls>").should eq(0_u32)
    tokenizer.token_to_id("<sep>").should eq(1_u32)

    result = tokenizer.add_tokens([
      Tokens::AddedToken.from("hello", false),
      Tokens::AddedToken.from("world", false),
    ])
    result.should eq(2_u64)
    tokenizer.token_to_id("hello").should eq(2_u32)
    tokenizer.token_to_id("world").should eq(3_u32)
  end

  it "lstrip_tokens" do
    bpe = Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    tokenizer = Tokens::TokenizerImpl.new(bpe)
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(true)
    ))

    tokenizer.add_special_tokens([Tokens::AddedToken.from("<mask>", true).lstrip(true)])

    input = "I saw a <mask> \u{1F63A}" # 😺
    output = tokenizer.encode(input, false)

    output.tokens.should eq(["ĠI", "Ġsaw", "Ġa", " <mask>", "ĠðŁĺ", "º"])
    output.offsets.should eq([
      {0_u32, 1_u32}, {1_u32, 5_u32}, {5_u32, 7_u32},
      {7_u32, 14_u32}, {14_u32, 19_u32}, {15_u32, 19_u32},
    ])
  end

  it "rstrip_tokens" do
    bpe = Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    tokenizer = Tokens::TokenizerImpl.new(bpe)
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)
    ))

    tokenizer.add_special_tokens([Tokens::AddedToken.from("<mask>", true).rstrip(true)])

    input = "I saw a <mask> \u{1F63A}"
    output = tokenizer.encode(input, false)

    output.tokens.should eq(["I", "Ġsaw", "Ġa", "Ġ", "<mask> ", "ðŁĺ", "º"])

    # With add_prefix_space=true, rstrip has the same behavior since prefix space trumps
    tokenizer2 = Tokens::TokenizerImpl.new(
      Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    )
    tokenizer2.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(true)
    ))
    tokenizer2.add_special_tokens([Tokens::AddedToken.from("<mask>", true).rstrip(true)])

    output2 = tokenizer2.encode(input, false)
    output2.tokens.should eq(["ĠI", "Ġsaw", "Ġa", "Ġ", "<mask> ", "ĠðŁĺ", "º"])
  end

  it "single_word_tokens" do
    bpe = Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    tokenizer = Tokens::TokenizerImpl.new(bpe)
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)
    ))

    # single_word=true: shouldn't split "dancing"
    tokenizer.add_special_tokens([Tokens::AddedToken.from("ing", true).single_word(true)])
    output = tokenizer.encode("I like dancing", false)
    output.tokens.should eq(["I", "Ġlike", "Ġdancing"])

    # single_word=false: should split "dancing"
    tokenizer2 = Tokens::TokenizerImpl.new(
      Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    )
    tokenizer2.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)
    ))
    tokenizer2.add_special_tokens([Tokens::AddedToken.from("ing", true).single_word(false)])
    output2 = tokenizer2.encode("I like dancing", false)
    output2.tokens.should eq(["I", "Ġlike", "Ġd", "anc", "ing"])
  end
end
