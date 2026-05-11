require "../spec_helper"

describe Tokens::Models::WordLevel do
  it "tokenize with UNK" do
    vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32} of String => UInt32
    wordlevel = Tokens::Models::WordLevel.build(
      vocab: vocab,
      unk_token: "<unk>"
    )

    tokens = wordlevel.tokenize("c")
    tokens.should eq([
      Tokens::Token.new(0_u32, "<unk>", {0_u32, 1_u32}),
    ])

    tokens = wordlevel.tokenize("a")
    tokens.should eq([
      Tokens::Token.new(1_u32, "a", {0_u32, 1_u32}),
    ])
  end

  it "tokenize missing UNK token raises error" do
    vocab = {"a" => 0_u32, "b" => 1_u32} of String => UInt32
    wordlevel = Tokens::Models::WordLevel.build(vocab: vocab)

    tokens = wordlevel.tokenize("a")
    tokens.should eq([
      Tokens::Token.new(0_u32, "a", {0_u32, 1_u32}),
    ])

    expect_raises(Tokens::Models::WordLevelError) do
      wordlevel.tokenize("c")
    end
  end

  it "token_to_id and id_to_token" do
    vocab = {"<unk>" => 0_u32, "hello" => 1_u32} of String => UInt32
    wordlevel = Tokens::Models::WordLevel.build(vocab: vocab)

    wordlevel.token_to_id("hello").should eq(1_u32)
    wordlevel.token_to_id("missing").should be_nil
    wordlevel.id_to_token(1_u32).should eq("hello")
    wordlevel.id_to_token(99_u32).should be_nil
  end

  it "vocab and vocab_size" do
    vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32} of String => UInt32
    wordlevel = Tokens::Models::WordLevel.build(vocab: vocab)

    wordlevel.vocab_size.should eq(3_u32)
    wordlevel.vocab["a"].should eq(1_u32)
  end

  it "default unk_token" do
    wordlevel = Tokens::Models::WordLevel.default
    wordlevel.unk_token.should eq("<unk>")
    wordlevel.vocab_size.should eq(0_u32)
  end

  it "serde" do
    wl = Tokens::Models::WordLevel.default
    wl_s = %({"type":"WordLevel","vocab":{},"unk_token":"<unk>"})
    wl.to_json.should eq(wl_s)
    Tokens::Models::WordLevel.from_json(wl_s).should eq(wl)
  end

  it "incomplete vocab serde" do
    vocab = {"<unk>" => 0_u32, "b" => 2_u32} of String => UInt32
    wordlevel = Tokens::Models::WordLevel.build(
      vocab: vocab,
      unk_token: "<unk>"
    )
    wl_s = %({"type":"WordLevel","vocab":{"<unk>":0,"b":2},"unk_token":"<unk>"})
    wordlevel.to_json.should eq(wl_s)
    Tokens::Models::WordLevel.from_json(wl_s).should eq(wordlevel)
  end

  it "deserialization should fail on missing fields" do
    expect_raises(JSON::ParseException, /missing field/) do
      Tokens::Models::WordLevel.from_json(%({"type":"WordLevel","vocab":{}}))
    end

    expect_raises(JSON::ParseException, /invalid/i) do
      Tokens::Models::WordLevel.from_json(%({"type":"WordPiece","vocab":{}}))
    end
  end
end

describe Tokens::Models::WordLevelTrainer do
  it "do_train" do
    word_counts = {
      "the"     => 25_u64,
      "roses"   => 22_u64,
      "are"     => 24_u64,
      "red"     => 12_u64,
      "voilets" => 10_u64,
      "blue"    => 16_u64,
    } of String => UInt64

    trainer = Tokens::Models::WordLevelTrainer.new(vocab_size: 5)
    model = Tokens::Models::WordLevel.default
    result = trainer.do_train(word_counts, model)
    result.should be_a(Array(Tokens::AddedToken))

    expected_vocab = {
      "the"   => 0_u32,
      "are"   => 1_u32,
      "roses" => 2_u32,
      "blue"  => 3_u32,
      "red"   => 4_u32,
    } of String => UInt32
    model.vocab.should eq(expected_vocab)

    # With min_frequency
    trainer = Tokens::Models::WordLevelTrainer.new(vocab_size: 5, min_frequency: 15_u64)
    model = Tokens::Models::WordLevel.default
    trainer.do_train(word_counts, model)

    expected_filtered = {
      "the"   => 0_u32,
      "are"   => 1_u32,
      "roses" => 2_u32,
      "blue"  => 3_u32,
    } of String => UInt32
    model.vocab.should eq(expected_filtered)
  end
end
