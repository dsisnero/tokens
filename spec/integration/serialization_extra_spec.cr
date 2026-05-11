require "../spec_helper"

describe "Serialization matrix - remaining tests" do
  it "bpe_serde" do
    bpe = Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
    ser = bpe.to_json
    de = Tokens::Models::BPE::BPE.from_json(ser)
    de.should eq(bpe)
  end

  it "wordpiece_serde" do
    wp = Tokens::Models::WordPiece.build(
      vocab: Tokens::Models::WordPiece.read_file("data/bert-base-uncased-vocab.txt")
    )
    ser = wp.to_json
    de = Tokens::Models::WordPiece.from_json(ser)
    de.should eq(wp)
  end

  it "wordlevel_serde" do
    vocab = Tokens::Models::WordLevel.read_file("data/gpt2-vocab.json")
    wl = Tokens::Models::WordLevel.build(vocab: vocab, unk_token: "<unk>")
    ser = wl.to_json
    de = Tokens::Models::WordLevel.from_json(ser)
    de.should eq(wl)
  end

  it "deserialize_long_file (albert)" do
    json = File.read("data/albert-base-v1-tokenizer.json")
    tokenizer = Tokens::TokenizerImpl.from_json(json)
    tokenizer.should be_a(Tokens::TokenizerImpl)
  end
end
