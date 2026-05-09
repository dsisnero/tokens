require "../spec_helper"

describe Tokens::PreTokenizers::Punctuation do
  it "isolates punctuation by default" do
    pretokenized = Tokens::PreTokenizedString.new("Hey friend!     How are you?!?")

    Tokens::PreTokenizers::Punctuation.default.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hey friend", {0_u32, 10_u32}},
        {"!", {10_u32, 11_u32}},
        {"     How are you", {11_u32, 27_u32}},
        {"?", {27_u32, 28_u32}},
        {"!", {28_u32, 29_u32}},
        {"?", {29_u32, 30_u32}},
      ])
  end

  it "deserializes its default shape" do
    Tokens::PreTokenizers::Punctuation.from_json(%({"type":"Punctuation"}))
      .should eq(Tokens::PreTokenizers::Punctuation.default)
  end

  it "rejects the wrong tagged type" do
    expect_raises(JSON::ParseException) do
      Tokens::PreTokenizers::Punctuation.from_json(%({"type":"WhitespaceSplit"}))
    end
  end
end
