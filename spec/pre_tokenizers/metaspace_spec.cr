require "../spec_helper"

describe Tokens::PreTokenizers::Metaspace do
  it "round-trips serialization and legacy loading" do
    metaspace = Tokens::PreTokenizers::Metaspace.new('_', Tokens::PreTokenizers::PrependScheme::Always, true)
    metaspace_json = %({"type":"Metaspace","replacement":"_","prepend_scheme":"always","split":true})
    metaspace.to_json.should eq(metaspace_json)
    Tokens::PreTokenizers::Metaspace.from_json(metaspace_json).should eq(metaspace)

    expect_raises(JSON::ParseException) do
      Tokens::PreTokenizers::Metaspace.from_json(%({"type":"Metaspace","replacement":"_","add_prefix_space":false,"prepend_scheme":"always"}))
    end

    legacy_json = %({"type":"Metaspace","str_rep":"_","replacement":"_","add_prefix_space":true,"prepend_scheme":"always"})
    Tokens::PreTokenizers::Metaspace.from_json(legacy_json).should eq(metaspace)

    Tokens::PreTokenizers::Metaspace.from_json(%({"type":"Metaspace","replacement":"_","add_prefix_space":true}))
      .should eq(metaspace)
  end

  it "replaces spaces and splits on the replacement" do
    pretok = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
    pretokenized = Tokens::PreTokenizedString.new("Hey friend!")

    pretok.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey", {0_u32, 6_u32}},
        {"▁friend!", {6_u32, 16_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey", {0_u32, 3_u32}},
        {"▁friend!", {3_u32, 11_u32}},
      ])
  end

  it "keeps multiple spaces as separate metaspace pieces" do
    pretok = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
    pretokenized = Tokens::PreTokenizedString.new("Hey   friend!")

    pretok.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey", {0_u32, 6_u32}},
        {"▁", {6_u32, 9_u32}},
        {"▁", {9_u32, 12_u32}},
        {"▁friend!", {12_u32, 22_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey", {0_u32, 3_u32}},
        {"▁", {3_u32, 4_u32}},
        {"▁", {4_u32, 5_u32}},
        {"▁friend!", {5_u32, 13_u32}},
      ])
  end

  it "matches non-legacy metaspace behaviors" do
    pretok = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
    pretok.set_prepend_scheme(Tokens::PreTokenizers::PrependScheme::Always)
    pretok.should eq(Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true))

    pretok.set_prepend_scheme(Tokens::PreTokenizers::PrependScheme::Never)
    pretok.should eq(Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Never, true))

    pretok.set_prepend_scheme(Tokens::PreTokenizers::PrependScheme::First)
    pretok.should eq(Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::First, true))

    regex = Regex.new("(<s>)")

    first_no_split = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::First, false)
    pretokenized = Tokens::PreTokenizedString.new("Hey my friend <s>how▁are you")
    pretokenized.split do |_, sequence|
      sequence.split(regex, Tokens::SplitDelimiterBehavior::Isolated).map { |slice| Tokens::Split.new(slice) }
    end
    first_no_split.pre_tokenize(pretokenized)
    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey▁my▁friend▁", {0_u32, 23_u32}},
        {"<s>", {23_u32, 26_u32}},
        {"how▁are▁you", {26_u32, 41_u32}},
      ])

    always_split = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
    always_split.pre_tokenize(pretokenized)
    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey", {0_u32, 6_u32}},
        {"▁my", {6_u32, 11_u32}},
        {"▁friend", {11_u32, 20_u32}},
        {"▁", {20_u32, 23_u32}},
        {"▁<s>", {23_u32, 29_u32}},
        {"▁how", {29_u32, 35_u32}},
        {"▁are", {35_u32, 41_u32}},
        {"▁you", {41_u32, 47_u32}},
      ])

    with_prefix = Tokens::PreTokenizedString.new(" Hey <s>how")
    with_prefix.split do |_, sequence|
      sequence.split(regex, Tokens::SplitDelimiterBehavior::Isolated).map { |slice| Tokens::Split.new(slice) }
    end
    first_no_split.pre_tokenize(with_prefix)
    with_prefix
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey▁", {0_u32, 9_u32}},
        {"<s>", {9_u32, 12_u32}},
        {"how", {12_u32, 15_u32}},
      ])

    many_splits = Tokens::PreTokenizedString.new(" Hey <s>how <s>are <s> you")
    many_splits.split do |_, sequence|
      sequence.split(regex, Tokens::SplitDelimiterBehavior::Isolated).map { |slice| Tokens::Split.new(slice) }
    end
    first_no_split.pre_tokenize(many_splits)
    many_splits
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"▁Hey▁", {0_u32, 9_u32}},
        {"<s>", {9_u32, 12_u32}},
        {"how▁", {12_u32, 18_u32}},
        {"<s>", {18_u32, 21_u32}},
        {"are▁", {21_u32, 27_u32}},
        {"<s>", {27_u32, 30_u32}},
        {"▁you", {30_u32, 36_u32}},
      ])
  end

  it "decodes metaspace tokens back to strings" do
    decoder = Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
    decoder.decode_chain(["▁Hey", "▁friend!"]).should eq(["Hey", " friend!"])

    Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Never, true)
      .decode_chain(["▁Hey", "▁friend!"]).should eq([" Hey", " friend!"])
  end
end
