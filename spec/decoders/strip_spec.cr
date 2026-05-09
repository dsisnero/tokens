require "../spec_helper"

describe Tokens::Decoders::Strip do
  it "strips repeated content from the configured sides" do
    decoder = Tokens::Decoders::Strip.new('H', 1, 0)
    decoder.decode_chain(["Hey", " friend!", "HHH"]).should eq(["ey", " friend!", "HH"])

    decoder = Tokens::Decoders::Strip.new('y', 0, 1)
    decoder.decode_chain(["Hey", " friend!"]).should eq(["He", " friend!"])
  end
end
