require "../spec_helper"

describe Tokens::PreTokenizers::Sequence do
  it "runs pre-tokenizers in order" do
    pretok = Tokens::PreTokenizers::Sequence.new([
      Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::WhitespaceSplit.new),
      Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::Punctuation.default),
    ])
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
end
