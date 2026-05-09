require "../spec_helper"

describe Tokens::PreTokenizers::Split do
  it "matches upstream delimiter behaviors" do
    regex = Tokens::PreTokenizers::SplitPattern.regex(%(\\w+|[^\\w\\s]+))

    {
      Tokens::SplitDelimiterBehavior::Removed => [
        {"How", {0_u32, 3_u32}},
        {"are", {4_u32, 7_u32}},
        {"you", {8_u32, 11_u32}},
        {"doing", {12_u32, 17_u32}},
        {"?", {17_u32, 18_u32}},
      ],
      Tokens::SplitDelimiterBehavior::Isolated => [
        {"How", {0_u32, 3_u32}},
        {" ", {3_u32, 4_u32}},
        {"are", {4_u32, 7_u32}},
        {" ", {7_u32, 8_u32}},
        {"you", {8_u32, 11_u32}},
        {" ", {11_u32, 12_u32}},
        {"doing", {12_u32, 17_u32}},
        {"?", {17_u32, 18_u32}},
      ],
      Tokens::SplitDelimiterBehavior::MergedWithPrevious => [
        {"How ", {0_u32, 4_u32}},
        {"are ", {4_u32, 8_u32}},
        {"you ", {8_u32, 12_u32}},
        {"doing", {12_u32, 17_u32}},
        {"?", {17_u32, 18_u32}},
      ],
      Tokens::SplitDelimiterBehavior::MergedWithNext => [
        {"How", {0_u32, 3_u32}},
        {" are", {3_u32, 7_u32}},
        {" you", {7_u32, 11_u32}},
        {" doing", {11_u32, 17_u32}},
        {"?", {17_u32, 18_u32}},
      ],
      Tokens::SplitDelimiterBehavior::Contiguous => [
        {"How", {0_u32, 3_u32}},
        {" ", {3_u32, 4_u32}},
        {"are", {4_u32, 7_u32}},
        {" ", {7_u32, 8_u32}},
        {"you", {8_u32, 11_u32}},
        {" ", {11_u32, 12_u32}},
        {"doing?", {12_u32, 18_u32}},
      ],
    }.each do |behavior, expected|
      pretokenized = Tokens::PreTokenizedString.new("How are you doing?")
      Tokens::PreTokenizers::Split.new(regex, behavior, true).pre_tokenize(pretokenized)

      pretokenized
        .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
        .map { |(s, o, _)| {s, o} }
        .should eq(expected)
    end
  end

  it "treats equivalent regex and string whitespace splits the same" do
    regex_input = Tokens::PreTokenizedString.new("Hey, man!")
    string_input = regex_input.clone

    Tokens::PreTokenizers::Split.new(
      Tokens::PreTokenizers::SplitPattern.regex("\\s+"),
      Tokens::SplitDelimiterBehavior::Removed,
      false
    ).pre_tokenize(regex_input)

    Tokens::PreTokenizers::Split.new(
      " ",
      Tokens::SplitDelimiterBehavior::Removed,
      false
    ).pre_tokenize(string_input)

    regex_input.should eq(string_input)
  end

  it "supports inverted splitting" do
    split_input = Tokens::PreTokenizedString.new("Hello Hello Hello")
    invert_input = split_input.clone

    Tokens::PreTokenizers::Split.new(" ", Tokens::SplitDelimiterBehavior::Removed, false).pre_tokenize(split_input)
    Tokens::PreTokenizers::Split.new("Hello", Tokens::SplitDelimiterBehavior::Removed, true).pre_tokenize(invert_input)

    split_input.should eq(invert_input)
  end

  it "round-trips serialization" do
    split = Tokens::PreTokenizers::Split.new("Hello", Tokens::SplitDelimiterBehavior::Removed, true)
    split_json = %({"type":"Split","pattern":{"String":"Hello"},"behavior":"Removed","invert":true})
    split.to_json.should eq(split_json)
    Tokens::PreTokenizers::Split.from_json(split_json).should eq(split)

    regex_split = Tokens::PreTokenizers::Split.new(
      Tokens::PreTokenizers::SplitPattern.regex("\\s+"),
      Tokens::SplitDelimiterBehavior::Isolated,
      false
    )
    regex_split_json = %({"type":"Split","pattern":{"Regex":"\\\\s+"},"behavior":"Isolated","invert":false})
    regex_split.to_json.should eq(regex_split_json)
    Tokens::PreTokenizers::Split.from_json(regex_split_json).should eq(regex_split)
  end
end
