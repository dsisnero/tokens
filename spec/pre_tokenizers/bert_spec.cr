require "../spec_helper"

describe Tokens::PreTokenizers::BertPreTokenizer do
  it "splits whitespace and punctuation" do
    pretok = Tokens::PreTokenizers::BertPreTokenizer.new
    pretokenized = Tokens::PreTokenizedString.new("Hey friend!     How are you?!?")

    pretok.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hey", {0_u32, 3_u32}},
        {"friend", {4_u32, 10_u32}},
        {"!", {10_u32, 11_u32}},
        {"How", {16_u32, 19_u32}},
        {"are", {20_u32, 23_u32}},
        {"you", {24_u32, 27_u32}},
        {"?", {27_u32, 28_u32}},
        {"!", {28_u32, 29_u32}},
        {"?", {29_u32, 30_u32}},
      ])
  end

  it "splits pre-separated chinese chars" do
    normalized = Tokens::NormalizedString.new("野口里佳 Noguchi Rika")
    normalized.transform(
      normalized.get.chars.flat_map { |char|
        if char.ord > 0x4E00
          [{' ', 0}, {char, 1}, {' ', 1}]
        else
          [{char, 0}]
        end
      },
      0
    )
    pretokenized = Tokens::PreTokenizedString.new(normalized)

    Tokens::PreTokenizers::BertPreTokenizer.new.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"野", {0_u32, 3_u32}},
        {"口", {3_u32, 6_u32}},
        {"里", {6_u32, 9_u32}},
        {"佳", {9_u32, 12_u32}},
        {"Noguchi", {13_u32, 20_u32}},
        {"Rika", {21_u32, 25_u32}},
      ])
  end
end
