require "../spec_helper"

describe Tokens::Decoders::ByteFallback do
  it "decodes byte fallback runs like upstream" do
    decoder = Tokens::Decoders::ByteFallback.new

    decoder.decode_chain(["Hey", "friend!"]).should eq(["Hey", "friend!"])
    decoder.decode_chain(["<0x61>"]).should eq(["a"])
    decoder.decode_chain(["<0xE5>"]).should eq(["�"])
    decoder.decode_chain(["<0xE5>", "<0x8f>"]).should eq(["�", "�"])
    decoder.decode_chain(["<0xE5>", "<0x8f>", "<0xab>"]).should eq(["叫"])
    decoder.decode_chain(["<0xE5>", "<0x8f>", "<0xab>", "a"]).should eq(["叫", "a"])
    decoder.decode_chain(["<0xE5>", "<0x8f>", "a"]).should eq(["�", "�", "a"])
  end
end
