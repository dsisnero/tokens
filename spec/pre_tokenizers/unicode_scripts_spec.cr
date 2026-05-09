require "../spec_helper"

describe Tokens::PreTokenizers::UnicodeScripts do
  it "splits on Unicode script boundaries" do
    pretok = Tokens::PreTokenizers::UnicodeScripts.new
    pretokenized = Tokens::PreTokenizedString.new("どこで生れ。Yes")

    pretok.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"どこで生れ", {0_u32, 15_u32}},
        {"。", {15_u32, 18_u32}},
        {"Yes", {18_u32, 21_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"どこで生れ", {0_u32, 15_u32}},
        {"。", {15_u32, 18_u32}},
        {"Yes", {18_u32, 21_u32}},
      ])
  end

  it "treats spaces as belonging to every script" do
    pretok = Tokens::PreTokenizers::UnicodeScripts.new
    pretokenized = Tokens::PreTokenizedString.new("Apples are りんご 林檎")

    pretok.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Apples are ", {0_u32, 11_u32}},
        {"りんご 林檎", {11_u32, 27_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Apples are ", {0_u32, 11_u32}},
        {"りんご 林檎", {11_u32, 27_u32}},
      ])
  end

  it "normalizes hiragana, katakana, and prolongation mark for sentencepiece behavior" do
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('京').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('太').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('い').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('グ').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('ー').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('a').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Latin)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('A').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Latin)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('0').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('$').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('@').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script('-').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScripts.fixed_script(' ').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Any)
  end
end

describe Tokens::PreTokenizers::UnicodeScriptsData do
  it "classifies Unicode scripts from the generated table" do
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('京').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('太').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Han)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('い').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Hiragana)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('グ').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Katakana)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('ー').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('a').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Latin)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('A').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Latin)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('0').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('$').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('@').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('-').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script(' ').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
    Tokens::PreTokenizers::UnicodeScriptsData.get_script('�').should eq(Tokens::PreTokenizers::UnicodeScriptsData::Script::Common)
  end
end
