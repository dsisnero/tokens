require "../spec_helper"

describe Tokens::ModelWrapper do
  it "serializes and deserializes BPE model" do
    vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32, "ab" => 3_u32}
    bpe = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{"<unk>":0,"a":1,"b":2,"ab":3},"merges":[["a","b"]]}))
    wrapper = Tokens::ModelWrapper.new(bpe)
    data = wrapper.to_json
    reconstructed = Tokens::ModelWrapper.from_json(data)
    reconstructed.should eq(wrapper)
  end

  it "deserializes BPE from legacy (no type) JSON" do
    legacy = %({"dropout":null,"unk_token":"<unk>","continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":true,"vocab":{"<unk>":0,"a":1,"b":2,"ab":3},"merges":[["a","b"]]})
    wrapper = Tokens::ModelWrapper.from_json(legacy)
    inner = wrapper.model
    inner.should be_a(Tokens::Models::BPE::BPE)
    inner.vocab["a"].should eq(1_u32)
  end

  it "serializes and deserializes WordLevel model" do
    vocab = {"<unk>" => 0_u32, "hello" => 1_u32}
    wl = Tokens::Models::WordLevel.build(vocab: vocab, unk_token: "<unk>")
    wrapper = Tokens::ModelWrapper.new(wl)
    data = wrapper.to_json
    reconstructed = Tokens::ModelWrapper.from_json(data)
    reconstructed.should eq(wrapper)
  end

  it "serializes and deserializes WordPiece model" do
    vocab = {"[UNK]" => 0_u32, "he" => 1_u32, "##llo" => 2_u32}
    wp = Tokens::Models::WordPiece.build(vocab: vocab)
    wrapper = Tokens::ModelWrapper.new(wp)
    data = wrapper.to_json
    reconstructed = Tokens::ModelWrapper.from_json(data)
    reconstructed.should eq(wrapper)
  end

  it "serializes and deserializes Unigram model" do
    vocab = [{"<unk>", 0.0_f64}, {"a", -0.5_f64}] of Tuple(String, Float64)
    u = Tokens::Models::Unigram::Unigram.from(vocab, 0, false)
    wrapper = Tokens::ModelWrapper.new(u)
    data = wrapper.to_json
    reconstructed = Tokens::ModelWrapper.from_json(data)
    reconstructed.should eq(wrapper)
  end

  it "delegates Model trait methods" do
    vocab = {"<unk>" => 0_u32, "hello" => 1_u32}
    wl = Tokens::Models::WordLevel.build(vocab: vocab)
    wrapper = Tokens::ModelWrapper.new(wl)

    wrapper.tokenize("hello").size.should eq(1)
    wrapper.token_to_id("hello").should eq(1_u32)
    wrapper.id_to_token(1_u32).should eq("hello")
    wrapper.vocab_size.should eq(2_u32)
    wrapper.vocab["hello"].should eq(1_u32)
  end

  it "rejects invalid model JSON" do
    invalid = %({"type":"BPE","dropout":null,"vocab":{},"merges":["a b c"]})
    expect_raises(Exception) do
      Tokens::ModelWrapper.from_json(invalid)
    end
  end
end

describe Tokens::TrainerWrapper do
  it "serializes and deserializes BpeTrainer" do
    trainer = Tokens::Models::BPE::BpeTrainer.new(
      min_frequency: 0_u64,
      vocab_size: 1000,
      show_progress: false,
      special_tokens: [] of Tokens::AddedToken,
      limit_alphabet: nil,
      initial_alphabet: Set(Char).new,
      continuing_subword_prefix: nil,
      end_of_word_suffix: nil,
      max_token_length: nil,
      words: {} of String => UInt64,
    )
    wrapper = Tokens::TrainerWrapper.new(trainer)
    data = wrapper.to_json
    data.should contain("\"BpeTrainer\"")
  end

  it "type-checks trainer/model mismatch" do
    trainer = Tokens::TrainerWrapper.new(
      Tokens::Models::BPE::BpeTrainer.new(
        min_frequency: 0_u64, vocab_size: 100, show_progress: false,
        special_tokens: [] of Tokens::AddedToken, limit_alphabet: nil,
        initial_alphabet: Set(Char).new, continuing_subword_prefix: nil,
        end_of_word_suffix: nil, max_token_length: nil, words: {} of String => UInt64,
      )
    )

    model = Tokens::ModelWrapper.new(Tokens::Models::Unigram::Unigram.default)
    expect_raises(Exception, /BpeTrainer can only train a BPE/) do
      trainer.train(model)
    end
  end
end
