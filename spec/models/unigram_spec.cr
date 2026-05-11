require "../spec_helper"

describe Tokens::Models::Unigram::Lattice do
  it "constructs empty" do
    lattice = Tokens::Models::Unigram::Lattice.new("", 1, 2)
    lattice.len.should eq(0)
  end

  it "constructs with sentence" do
    lattice = Tokens::Models::Unigram::Lattice.new("test", 1, 2)
    lattice.len.should eq(4)
    lattice.surface(0).should eq("test")
    lattice.surface(1).should eq("est")
    lattice.surface(2).should eq("st")
    lattice.surface(3).should eq("t")

    lattice.begin_nodes[4][0].id.should eq(2) # EOS
    lattice.end_nodes[0][0].id.should eq(1)   # BOS
  end

  it "constructs with multi-byte chars" do
    lattice = Tokens::Models::Unigram::Lattice.new("テストab", 1, 2)
    lattice.len.should eq(11) # 3+3+3+1+1 = 11 bytes
    lattice.surface(0).should eq("テストab")
    lattice.surface(1).should eq("ストab")
    lattice.surface(2).should eq("トab")
    lattice.surface(3).should eq("ab")
    lattice.surface(4).should eq("b")
  end

  it "insert and piece" do
    lattice = Tokens::Models::Unigram::Lattice.new("ABあい", 1, 2)

    lattice.insert(0, 1, 0.0, 3) # "A"
    lattice.insert(1, 1, 0.0, 4) # "B"
    lattice.insert(2, 3, 0.0, 5) # "あ"
    lattice.insert(5, 3, 0.0, 6) # "い"
    lattice.insert(0, 2, 0.0, 7) # "AB"
    lattice.insert(1, 4, 0.0, 8) # "Bあ"
    lattice.insert(2, 6, 0.0, 9) # "あい"

    # BOS + EOS + 7 inserted = 9 nodes
    lattice.nodes.size.should eq(9)

    n0 = lattice.nodes[2] # "A"
    n1 = lattice.nodes[3] # "B"
    n2 = lattice.nodes[4] # "あ"
    n3 = lattice.nodes[5] # "い"
    n4 = lattice.nodes[6] # "AB"
    n5 = lattice.nodes[7] # "Bあ"
    n6 = lattice.nodes[8] # "あい"

    lattice.piece(n0).should eq("A")
    lattice.piece(n1).should eq("B")
    lattice.piece(n2).should eq("あ")
    lattice.piece(n3).should eq("い")
    lattice.piece(n4).should eq("AB")
    lattice.piece(n5).should eq("Bあ")
    lattice.piece(n6).should eq("あい")

    n0.pos.should eq(0)
    n1.pos.should eq(1)
    n2.pos.should eq(2)
    n3.pos.should eq(5)
    n4.pos.should eq(0)
    n5.pos.should eq(1)
    n6.pos.should eq(2)

    n0.length.should eq(1)
    n1.length.should eq(1)
    n2.length.should eq(3)
    n3.length.should eq(3)
    n4.length.should eq(2)
    n5.length.should eq(4)
    n6.length.should eq(6)
  end

  it "viterbi returns best path" do
    lattice = Tokens::Models::Unigram::Lattice.new("ABC", 1, 2)
    lattice.viterbi.should eq([] of Tokens::Models::Unigram::LatticeNode)

    lattice.insert(0, 1, 0.0, 3)
    lattice.insert(1, 1, 0.0, 4)
    lattice.insert(2, 1, 0.0, 5)
    lattice.viterbi.size.should eq(3)
  end

  it "viterbi2 picks best segmentation" do
    lattice = Tokens::Models::Unigram::Lattice.new("ABC", 1, 2)

    lattice.insert(0, 1, 0.0, 3) # A
    lattice.insert(1, 1, 0.0, 4) # B
    lattice.insert(2, 1, 0.0, 5) # C

    lattice.tokens.should eq(["A", "B", "C"])

    lattice.insert(0, 2, 2.0, 6) # AB (score 2.0)
    lattice.tokens.should eq(["AB", "C"])

    lattice.insert(1, 2, 5.0, 7) # BC (score 5.0)
    lattice.tokens.should eq(["A", "BC"])

    lattice.insert(0, 3, 10.0, 8) # ABC (score 10.0)
    lattice.tokens.should eq(["ABC"])
  end

  it "nbest" do
    lattice = Tokens::Models::Unigram::Lattice.new("ABC", 1, 2)
    lattice.insert(0, 1, 0.0, 3)
    lattice.insert(1, 1, 0.0, 4)
    lattice.insert(2, 1, 0.0, 5)
    lattice.insert(0, 2, 2.0, 6)
    lattice.insert(1, 2, 5.0, 7)
    lattice.insert(0, 3, 10.0, 8)

    nbests = lattice.nbest_tokens(10)
    nbests.should eq([
      ["ABC"],
      ["A", "BC"],
      ["AB", "C"],
      ["A", "B", "C"],
    ])

    lattice.nbest_tokens(0).should be_empty
    lattice.nbest_tokens(1).should eq([["ABC"]])
  end

  it "log_sum_exp" do
    vals = [1.0_f64, 2.0_f64, 3.0_f64]
    x = 0.0_f64
    vals.each_with_index do |y, i|
      # We test via the lattice instance method
      lattice = Tokens::Models::Unigram::Lattice.new("a", 1, 2)
      x = lattice.log_sum_exp(x, y, i == 0)
    end
    expected = vals.map { |v| Math.exp(v) }.sum.try { |s| Math.log(s) } || 0.0
    (x - expected).abs.should be < 0.001
  end
end

describe Tokens::Models::Unigram::Unigram do
  it "constructs from vocab with unk_id" do
    vocab = [
      {"<unk>", 0.0_f64},
      {"a", -0.5_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(vocab, 0, false)
    model.unk_id.should eq(0)
    model.vocab_size.should eq(2_u32)
  end

  it "populate_nodes UNK only" do
    pieces = [{"<unk>", 0.0_f64}] of Tuple(String, Float64)
    model = Tokens::Models::Unigram::Unigram.from(pieces, 0, false)

    lattice = Tokens::Models::Unigram::Lattice.new("abc", model.bos_id, model.eos_id)
    model.populate_nodes(lattice)

    lattice.begin_nodes[0].size.should eq(1)
    lattice.begin_nodes[1].size.should eq(1)
    lattice.begin_nodes[2].size.should eq(1)
    lattice.begin_nodes[0][0].id.should eq(0)
    lattice.begin_nodes[1][0].id.should eq(0)
    lattice.begin_nodes[2][0].id.should eq(0)
    lattice.begin_nodes[0][0].node_id.should eq(2)
    lattice.begin_nodes[1][0].node_id.should eq(3)
    lattice.begin_nodes[2][0].node_id.should eq(4)
  end

  it "populate_nodes with vocab" do
    pieces = [
      {"<unk>", 0.0_f64},
      {"a", 0.1_f64},
      {"b", 0.2_f64},
      {"ab", 0.3_f64},
      {"bc", 0.4_f64},
    ] of Tuple(String, Float64)
    model = Tokens::Models::Unigram::Unigram.from(pieces, 0, false)

    lattice = Tokens::Models::Unigram::Lattice.new("abc", model.bos_id, model.eos_id)
    model.populate_nodes(lattice)

    lattice.begin_nodes[0].size.should eq(2) # a, ab
    lattice.begin_nodes[1].size.should eq(2) # b, bc
    lattice.begin_nodes[2].size.should eq(1) # c(unk)

    lattice.begin_nodes[0][0].id.should eq(1) # "a"
    lattice.begin_nodes[0][1].id.should eq(3) # "ab"
    lattice.begin_nodes[1][0].id.should eq(2) # "b"
    lattice.begin_nodes[1][1].id.should eq(4) # "bc"
    lattice.begin_nodes[2][0].id.should eq(0) # UNK
  end

  it "encode chooses best path" do
    pieces = [
      {"<unk>", 0.0_f64},
      {"a", 0.0_f64},
      {"b", 0.0_f64},
      {"c", 0.0_f64},
      {"d", 0.0_f64},
      {"cd", 1.0_f64},
      {"ab", 2.0_f64},
      {"abc", 5.0_f64},
      {"abcd", 10.0_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(pieces, 0, false)
    result = model.encode("abcd")
    result.should eq(["abcd"])
  end

  it "encode2" do
    pieces = [
      {"<unk>", 0.0_f64},
      {"ab", 0.0_f64},
      {"cd", -0.1_f64},
    ] of Tuple(String, Float64)

    model = Tokens::Models::Unigram::Unigram.from(pieces, 0, false)
    result = model.encode("abcd")
    result.should eq(["ab", "cd"])
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
