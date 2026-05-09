require "../spec_helper"

describe Tokens::Decoders::CTC do
  it "decodes the handmade sample" do
    decoder = Tokens::Decoders::CTC.default
    tokens = "<pad> <pad> h e e l l <pad> l o o o <pad>".split(' ')

    decoder.decode_chain(tokens).should eq(["h", "e", "l", "l", "o"])
  end

  it "decodes the handmade sample with delimiter" do
    decoder = Tokens::Decoders::CTC.default
    tokens = "<pad> <pad> h e e l l <pad> l o o o <pad> <pad> | <pad> w o o o r <pad> <pad> l l d <pad> <pad> <pad> <pad>".split(' ')

    decoder.decode_chain(tokens).should eq(["h", "e", "l", "l", "o", " ", "w", "o", "r", "l", "d"])
  end

  it "decodes the librispeech sample" do
    decoder = Tokens::Decoders::CTC.default
    tokens = "<pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> A | | <pad> M <pad> <pad> <pad> <pad> A <pad> <pad> N <pad> <pad> <pad> | | | <pad> <pad> <pad> <pad> S <pad> <pad> <pad> A I <pad> D D | | T T <pad> O <pad> | | T H E E | | | <pad> U U <pad> N N <pad> I <pad> <pad> V <pad> <pad> <pad> E R R <pad> <pad> <pad> S E E | | <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> S S <pad> <pad> <pad> <pad> I <pad> R R <pad> <pad> | | | <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> I <pad> <pad> <pad> | <pad> <pad> <pad> E X <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> I <pad> S <pad> <pad> T <pad> <pad> | | <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad>".split(' ')

    decoder.decode_chain(tokens).should eq([
      "A", " ", "M", "A", "N", " ", "S", "A", "I", "D", " ", "T", "O", " ", "T", "H",
      "E", " ", "U", "N", "I", "V", "E", "R", "S", "E", " ", "S", "I", "R", " ", "I",
      " ", "E", "X", "I", "S", "T", " ",
    ])
  end

  it "decodes the second librispeech sample" do
    decoder = Tokens::Decoders::CTC.default
    tokens = "<pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> H <pad> I <pad> S S | | <pad> <pad> <pad> I N <pad> <pad> S <pad> T T <pad> <pad> A N C C T <pad> | | | | | <pad> <pad> <pad> <pad> P <pad> <pad> <pad> <pad> A <pad> <pad> N N N <pad> <pad> I <pad> C <pad> <pad> | | <pad> W <pad> <pad> A S <pad> | | <pad> <pad> <pad> F <pad> <pad> O L <pad> <pad> L L O O W E E D | | <pad> B <pad> <pad> <pad> Y <pad> | | | A | | <pad> S S S <pad> M M <pad> <pad> <pad> A L L <pad> <pad> <pad> <pad> L <pad> | | | <pad> <pad> <pad> <pad> S H H <pad> <pad> <pad> <pad> A R R <pad> <pad> P <pad> <pad> | <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> B <pad> <pad> L L <pad> <pad> <pad> <pad> <pad> O W W <pad> <pad> | | | <pad> <pad> <pad> <pad> <pad> <pad> <pad> H <pad> <pad> <pad> <pad> <pad> <pad> <pad> I G H H | | <pad> <pad> O N <pad> | | H <pad> I S S | | <pad> <pad> C H H <pad> <pad> <pad> E <pad> S S <pad> T T <pad> <pad> | | | <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad> <pad>".split(' ')

    decoder.decode_chain(tokens).should eq([
      "H", "I", "S", " ", "I", "N", "S", "T", "A", "N", "C", "T", " ", "P", "A", "N",
      "I", "C", " ", "W", "A", "S", " ", "F", "O", "L", "L", "O", "W", "E", "D", " ",
      "B", "Y", " ", "A", " ", "S", "M", "A", "L", "L", " ", "S", "H", "A", "R", "P",
      " ", "B", "L", "O", "W", " ", "H", "I", "G", "H", " ", "O", "N", " ", "H", "I",
      "S", " ", "C", "H", "E", "S", "T", " ",
    ])
  end
end
