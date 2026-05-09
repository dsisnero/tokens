require "../spec_helper"

describe Tokens::PreTokenizers::Whitespace do
  it "splits words and punctuation" do
    pretok = Tokens::PreTokenizers::Whitespace.new

    {
      "Hey man!"           => [{"Hey", {0_u32, 3_u32}}, {"man", {4_u32, 7_u32}}, {"!", {7_u32, 8_u32}}],
      "How are you doing?" => [{"How", {0_u32, 3_u32}}, {"are", {4_u32, 7_u32}}, {"you", {8_u32, 11_u32}}, {"doing", {12_u32, 17_u32}}, {"?", {17_u32, 18_u32}}],
      "\n"                 => [] of Tuple(String, Tuple(UInt32, UInt32)),
    }.each do |input, expected|
      pretokenized = Tokens::PreTokenizedString.new(input)
      pretok.pre_tokenize(pretokenized)

      pretokenized
        .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
        .map { |(s, o, _)| {s, o} }
        .should eq(expected)
    end
  end
end

describe Tokens::PreTokenizers::WhitespaceSplit do
  it "splits only on whitespace" do
    pretok = Tokens::PreTokenizers::WhitespaceSplit.new

    {
      "Hey man!"        => [{"Hey", {0_u32, 3_u32}}, {"man!", {4_u32, 8_u32}}],
      "Hey, man, Good?" => [{"Hey,", {0_u32, 4_u32}}, {"man,", {5_u32, 9_u32}}, {"Good?", {10_u32, 15_u32}}],
    }.each do |input, expected|
      pretokenized = Tokens::PreTokenizedString.new(input)
      pretok.pre_tokenize(pretokenized)

      pretokenized
        .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
        .map { |(s, o, _)| {s, o} }
        .should eq(expected)
    end
  end
end
