require "../spec_helper"

describe Tokens::Decoders::WordPiece do
  it "decodes the upstream sample" do
    decoder = Tokens::Decoders::WordPiece.new("##", false)

    decoder.decode(["##uelo", "Ara", "##új", "##o", "No", "##guera"]).should eq("##uelo Araújo Noguera")
  end
end
