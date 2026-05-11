require "../spec_helper"

describe Tokens::Models::WordPiece do
  it "tokenizes with greedy longest-match" do
    vocab = {
      "[UNK]" => 0_u32,
      "he"    => 1_u32,
      "##llo" => 2_u32,
      "wo"    => 3_u32,
      "##rld" => 4_u32,
      "a"     => 5_u32,
    } of String => UInt32

    wp = Tokens::Models::WordPiece.build(vocab: vocab)

    # Full match
    tokens = wp.tokenize("a")
    tokens.should eq([Tokens::Token.new(5_u32, "a", {0_u32, 1_u32})])

    # Two-part match
    tokens = wp.tokenize("hello")
    tokens.should eq([
      Tokens::Token.new(1_u32, "he", {0_u32, 2_u32}),
      Tokens::Token.new(2_u32, "##llo", {2_u32, 5_u32}),
    ])

    tokens = wp.tokenize("world")
    tokens.should eq([
      Tokens::Token.new(3_u32, "wo", {0_u32, 2_u32}),
      Tokens::Token.new(4_u32, "##rld", {2_u32, 5_u32}),
    ])
  end

  it "falls back to UNK for unknown words" do
    vocab = {
      "[UNK]" => 0_u32,
      "he"    => 1_u32,
    } of String => UInt32

    wp = Tokens::Models::WordPiece.build(vocab: vocab)

    tokens = wp.tokenize("xyz")
    tokens.should eq([Tokens::Token.new(0_u32, "[UNK]", {0_u32, 3_u32})])
  end

  it "raises MissingUnkToken when UNK is not in vocab" do
    vocab = {"a" => 0_u32} of String => UInt32
    wp = Tokens::Models::WordPiece.build(vocab: vocab, unk_token: "[UNK]")

    expect_raises(Tokens::Models::WordPieceMissingUnk) do
      wp.tokenize("xyz")
    end
  end

  it "uses max_input_chars_per_word" do
    vocab = {
      "[UNK]"      => 0_u32,
      "abcdefghij" => 1_u32,
    } of String => UInt32

    wp = Tokens::Models::WordPiece.build(vocab: vocab, max_input_chars_per_word: 5)

    # Word with > 5 chars
    tokens = wp.tokenize("abcdefghij")
    tokens.should eq([Tokens::Token.new(0_u32, "[UNK]", {0_u32, 10_u32})])
  end

  it "token_to_id and id_to_token" do
    vocab = {"[UNK]" => 0_u32, "hello" => 1_u32} of String => UInt32
    wp = Tokens::Models::WordPiece.build(vocab: vocab)

    wp.token_to_id("hello").should eq(1_u32)
    wp.token_to_id("missing").should be_nil
    wp.id_to_token(1_u32).should eq("hello")
  end

  it "default values" do
    wp = Tokens::Models::WordPiece.default
    wp.unk_token.should eq("[UNK]")
    wp.continuing_subword_prefix.should eq("##")
    wp.max_input_chars_per_word.should eq(100_u32)
  end

  it "serde" do
    wp = Tokens::Models::WordPiece.default
    wp_s = %({"type":"WordPiece","unk_token":"[UNK]","continuing_subword_prefix":"##","max_input_chars_per_word":100,"vocab":{}})
    wp.to_json.should eq(wp_s)
    Tokens::Models::WordPiece.from_json(wp_s).should eq(wp)
  end

  it "deserialization should fail on missing fields or wrong type" do
    expect_raises(JSON::ParseException, /missing field/) do
      Tokens::Models::WordPiece.from_json(%({"type":"WordPiece","continuing_subword_prefix":"##","max_input_chars_per_word":100,"vocab":{}}))
    end

    expect_raises(JSON::ParseException, /invalid/i) do
      Tokens::Models::WordPiece.from_json(%({"type":"WordLevel","unk_token":"[UNK]","vocab":{}}))
    end
  end
end

describe Tokens::Models::WordPieceTrainer do
  it "has delegate properties from BpeTrainer" do
    trainer = Tokens::Models::WordPieceTrainer.new(vocab_size: 1000, min_frequency: 2_u64)
    trainer.vocab_size.should eq(1000)
    trainer.min_frequency.should eq(2_u64)
  end

  it "responds to train" do
    trainer = Tokens::Models::WordPieceTrainer.new(vocab_size: 5)
    model = Tokens::Models::WordPiece.default
    result = trainer.train(model)
    result.should be_a(Array(Tokens::AddedToken))
  end

  it "has builder method" do
    trainer = Tokens::Models::WordPieceTrainer.new
    trainer.should_show_progress?.should be_true
  end
end
