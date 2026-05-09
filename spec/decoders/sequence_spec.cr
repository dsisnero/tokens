require "../spec_helper"

describe Tokens::Decoders::Sequence do
  it "chains decoders in order" do
    decoder = Tokens::Decoders::Sequence.new([
      Tokens::DecoderWrapper.from(Tokens::Decoders::CTC.default),
      Tokens::DecoderWrapper.from(Tokens::PreTokenizers::Metaspace.default),
    ])
    tokens = ["▁", "▁", "H", "H", "i", "i", "▁", "y", "o", "u"]

    decoder.decode(tokens).should eq("Hi you")
  end
end
