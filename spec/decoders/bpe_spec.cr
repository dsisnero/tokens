require "../spec_helper"

describe Tokens::Decoders::BPEDecoder do
  it "replaces the suffix with spaces except on the final token" do
    decoder = Tokens::Decoders::BPEDecoder.default

    decoder.decode_chain(["Hel</w>", "lo</w>", "!</w>"]).should eq(["Hel ", "lo ", "!"])
    decoder.decode(["Hel</w>", "lo</w>", "!</w>"]).should eq("Hel lo !")
  end
end
