require "../spec_helper"

describe Tokens::PreTokenizers::Digits do
  it "keeps contiguous numbers together by default" do
    pretok = Tokens::PreTokenizers::Digits.new(false)
    pretokenized = Tokens::PreTokenizedString.new("Hey 123 friend!")

    pretok.pre_tokenize(pretokenized)

    expected = [
      {"Hey ", {0_u32, 4_u32}},
      {"123", {4_u32, 7_u32}},
      {" friend!", {7_u32, 15_u32}},
    ]

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq(expected)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq(expected)
  end

  it "splits individual digits when configured" do
    pretok = Tokens::PreTokenizers::Digits.new(true)
    pretokenized = Tokens::PreTokenizedString.new("Hey 123 friend!")

    pretok.pre_tokenize(pretokenized)

    expected = [
      {"Hey ", {0_u32, 4_u32}},
      {"1", {4_u32, 5_u32}},
      {"2", {5_u32, 6_u32}},
      {"3", {6_u32, 7_u32}},
      {" friend!", {7_u32, 15_u32}},
    ]

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq(expected)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq(expected)
  end
end
