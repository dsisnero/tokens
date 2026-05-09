require "../spec_helper"

describe Tokens::PreTokenizers::FixedLength do
  it "chunks by the default configured length" do
    pretok = Tokens::PreTokenizers::FixedLength.new(5)

    {
      "Hello world" => [{"Hello", {0_u32, 5_u32}}, {" worl", {5_u32, 10_u32}}, {"d", {10_u32, 11_u32}}],
      "Short"       => [{"Short", {0_u32, 5_u32}}],
      ""            => [] of Tuple(String, Tuple(UInt32, UInt32)),
    }.each do |input, expected|
      pretokenized = Tokens::PreTokenizedString.new(input)
      pretok.pre_tokenize(pretokenized)

      pretokenized
        .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
        .map { |(s, o, _)| {s, o} }
        .should eq(expected)
    end
  end

  it "supports custom length" do
    pretokenized = Tokens::PreTokenizedString.new("Hello world")

    Tokens::PreTokenizers::FixedLength.new(3).pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hel", {0_u32, 3_u32}},
        {"lo ", {3_u32, 6_u32}},
        {"wor", {6_u32, 9_u32}},
        {"ld", {9_u32, 11_u32}},
      ])
  end

  it "respects utf8 boundaries" do
    pretokenized = Tokens::PreTokenizedString.new("Hello 👋 world")

    Tokens::PreTokenizers::FixedLength.new(3).pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hel", {0_u32, 3_u32}},
        {"lo ", {3_u32, 6_u32}},
        {"👋 w", {6_u32, 12_u32}},
        {"orl", {12_u32, 15_u32}},
        {"d", {15_u32, 16_u32}},
      ])
  end
end
