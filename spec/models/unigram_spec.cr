require "../spec_helper"

describe Tokens::Models::Unigram::Unigram do
  it "constructs from vocab with unk_id" do
    vocab = [
      {"<unk>", 0.0_f64},
      {"a", -0.5_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(vocab, 0, false)
    model.should be_a(Tokens::Models::Unigram::Unigram)
    model.unk_id.should eq(0)
    model.vocab_size.should eq(2_u32)
  end

  it "rejects empty vocabulary" do
    expect_raises(Tokens::Models::Unigram::EmptyVocabulary) do
      Tokens::Models::Unigram::Unigram.from([] of Tuple(String, Float64), 0, false)
    end
  end

  it "rejects unk_id out of range" do
    expect_raises(Tokens::Models::Unigram::UnkIdNotInVocabulary) do
      Tokens::Models::Unigram::Unigram.from([{"a", 0.0_f64}], 5, false)
    end
  end

  it "allows unk_id to be nil" do
    vocab = [{"a", -0.5_f64}] of Tuple(String, Float64)
    model = Tokens::Models::Unigram::Unigram.from(vocab, nil, false)
    model.unk_id.should be_nil
  end

  it "token_to_id and id_to_token" do
    vocab = [
      {"<unk>", 0.0_f64},
      {"hello", -0.5_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(vocab, 0, false)
    model.token_to_id("hello").should eq(1_u32)
    model.token_to_id("missing").should be_nil
    model.id_to_token(0_u32).should eq("<unk>")
    model.id_to_token(1_u32).should eq("hello")
  end

  it "default model" do
    model = Tokens::Models::Unigram::Unigram.default
    model.unk_id.should eq(0)
    model.vocab_size.should eq(1_u32)
    model.byte_fallback?.should be_false
  end

  it "serialization round-trip" do
    vocab = [
      {"<unk>", 0.0_f64},
      {"a", -0.5_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(vocab, 0, false)
    data = model.to_json
    reconstructed = Tokens::Models::Unigram::Unigram.from_json(data)
    reconstructed.should eq(model)
  end

  it "serialization with unk_id not zero" do
    vocab = [
      {"a", -0.5_f64},
      {"<unk>", 0.0_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(vocab, 1, false)
    data = model.to_json
    reconstructed = Tokens::Models::Unigram::Unigram.from_json(data)
    reconstructed.should eq(model)
  end

  it "serialization with no unk_id" do
    vocab = [{"a", -0.5_f64}] of Tuple(String, Float64)
    model = Tokens::Models::Unigram::Unigram.from(vocab, nil, false)
    data = model.to_json
    reconstructed = Tokens::Models::Unigram::Unigram.from_json(data)
    reconstructed.should eq(model)
  end

  it "byte_fallback serialization" do
    vocab = [{"<unk>", 0.0_f64}] of Tuple(String, Float64)
    model = Tokens::Models::Unigram::Unigram.from(vocab, 0, true)
    model.byte_fallback?.should be_true
    data = model.to_json
    data.should contain("\"byte_fallback\":true")
    reconstructed = Tokens::Models::Unigram::Unigram.from_json(data)
    reconstructed.byte_fallback?.should be_true
  end

  it "rejects wrong type in JSON" do
    expect_raises(JSON::ParseException, /invalid/i) do
      Tokens::Models::Unigram::Unigram.from_json(%({"type":"BPE","vocab":[]}))
    end
  end
end

describe Tokens::Models::Unigram::Trie do
  it "performs common prefix search" do
    trie = Tokens::Models::Unigram::Trie(UInt8).new
    trie.push("ab".bytes)
    trie.push("abc".bytes)
    trie.push("bc".bytes)

    results = trie.common_prefix_search("abcd".bytes.each)
    results.size.should eq(2)
    results[0].should eq("ab".bytes)
    results[1].should eq("abc".bytes)

    results = trie.common_prefix_search("bcd".bytes.each)
    results.size.should eq(1)
    results[0].should eq("bc".bytes)

    results = trie.common_prefix_search("xyz".bytes.each)
    results.size.should eq(0)
  end
end
