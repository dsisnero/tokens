require "../spec_helper"

describe Tokens::Decoders::Fuse do
  it "fuses all tokens into one string" do
    decoder = Tokens::Decoders::Fuse.new

    decoder.decode_chain(["Hey", " friend!"]).should eq(["Hey friend!"])
  end
end
