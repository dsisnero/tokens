require "../spec_helper"

describe Tokens::PreTokenizers::ByteLevel do
  it "pre-tokenizes with the GPT-2 regex" do
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)
    pretokenized = Tokens::PreTokenizedString.new("Hello my friend, how is your day going?")

    bytelevel.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hello", {0_u32, 5_u32}},
        {"Ġmy", {5_u32, 8_u32}},
        {"Ġfriend", {8_u32, 15_u32}},
        {",", {15_u32, 16_u32}},
        {"Ġhow", {16_u32, 20_u32}},
        {"Ġis", {20_u32, 23_u32}},
        {"Ġyour", {23_u32, 28_u32}},
        {"Ġday", {28_u32, 32_u32}},
        {"Ġgoing", {32_u32, 38_u32}},
        {"?", {38_u32, 39_u32}},
      ])
  end

  it "supports byte-level normalization without regex splitting" do
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.use_regex(false)
    pretokenized = Tokens::PreTokenizedString.new("Hello my friend, how is your day going?")

    bytelevel.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"ĠHelloĠmyĠfriend,ĠhowĠisĠyourĠdayĠgoing?", {0_u32, 39_u32}},
      ])
  end

  it "decodes byte-level tokens" do
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)
    bytelevel.decode_chain(["Hello", "Ġmy", "Ġfriend", ",", "Ġhow", "Ġis", "Ġyour", "Ġday", "Ġgoing", "?"])
      .should eq(["Hello my friend, how is your day going?"])
  end

  it "adds a prefix space consistently" do
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(true)

    [
      " Hello my friend, how is your day going?",
      "Hello my friend, how is your day going?",
    ].each do |input|
      pretokenized = Tokens::PreTokenizedString.new(input)
      bytelevel.pre_tokenize(pretokenized)

      pretokenized
        .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
        .map { |(s, o, _)| {s, o} }
        .should eq([
          {"ĠHello", {0_u32, 7_u32}},
          {"Ġmy", {7_u32, 11_u32}},
          {"Ġfriend", {11_u32, 19_u32}},
          {",", {19_u32, 20_u32}},
          {"Ġhow", {20_u32, 25_u32}},
          {"Ġis", {25_u32, 29_u32}},
          {"Ġyour", {29_u32, 35_u32}},
          {"Ġday", {35_u32, 40_u32}},
          {"Ġgoing", {40_u32, 47_u32}},
          {"?", {47_u32, 48_u32}},
        ])
    end
  end

  it "decodes correctly even when tokens are separated into characters" do
    samples = [
      %(A Nuskhuri abbreviation of იესუ ქრისტე ( iesu kriste ) " Jesus Christ "),
      %(An equal number have descenders , like p or q in English : გ , დ , ე , ვ , კ , ლ , ჟ , ტ , უ , ფ , ღ , ყ , ც),
    ]
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)

    samples.each do |sample|
      pretokenized = Tokens::PreTokenizedString.new(sample)
      bytelevel.pre_tokenize(pretokenized)
      separated_tokens = pretokenized
        .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
        .flat_map { |(s, _, _)| s.chars.map(&.to_s) }

      bytelevel.decode_chain(separated_tokens).join("").should eq(sample)
    end
  end

  it "handles newlines" do
    pretokenized = Tokens::PreTokenizedString.new("Hello there\nHello there")
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)

    bytelevel.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hello", {0_u32, 5_u32}},
        {"Ġthere", {5_u32, 11_u32}},
        {"Ċ", {11_u32, 12_u32}},
        {"Hello", {12_u32, 17_u32}},
        {"Ġthere", {17_u32, 23_u32}},
      ])
  end

  it "handles multiple whitespace chunks" do
    pretokenized = Tokens::PreTokenizedString.new("Hello there       dear")
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)

    bytelevel.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"Hello", {0_u32, 5_u32}},
        {"Ġthere", {5_u32, 11_u32}},
        {"ĠĠĠĠĠĠ", {11_u32, 17_u32}},
        {"Ġdear", {17_u32, 22_u32}},
      ])
  end

  it "preserves offsets when a single character expands to multiple bytes" do
    input = "i⭢j"
    pretokenized = Tokens::PreTokenizedString.new(input)
    bytelevel = Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(false)

    bytelevel.pre_tokenize(pretokenized)

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"i", {0_u32, 1_u32}},
        {"âŃ¢", {1_u32, 4_u32}},
        {"j", {4_u32, 5_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Normalized, Tokens::OffsetType::Byte)
      .map { |(s, o, _)| {s, o} }
      .should eq([
        {"i", {0_u32, 1_u32}},
        {"âŃ¢", {1_u32, 7_u32}},
        {"j", {7_u32, 8_u32}},
      ])

    pretokenized
      .get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
      .map { |(_, o, _)| input.byte_slice(o[0].to_i, (o[1] - o[0]).to_i).not_nil! }
      .should eq(["i", "⭢", "j"])
  end

  it "trims offsets correctly for pre-tokenized inputs" do
    encoding = Tokens::Encoding.new(
      ids: Array(UInt32).new(5, 0_u32),
      type_ids: [] of UInt32,
      tokens: ["Ġl", "ove", "Ġl", "ove"],
      words: [] of UInt32?,
      offsets: [{0_u32, 1_u32}, {1_u32, 4_u32}, {0_u32, 1_u32}, {1_u32, 4_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      overflowing: [] of Tokens::Encoding,
      sequence_ranges: {} of UInt64 => Range(UInt64, UInt64)
    )

    Tokens::PreTokenizers.process_offsets(encoding, true)

    encoding.should eq(Tokens::Encoding.new(
      ids: Array(UInt32).new(5, 0_u32),
      type_ids: [] of UInt32,
      tokens: ["Ġl", "ove", "Ġl", "ove"],
      words: [] of UInt32?,
      offsets: [{0_u32, 1_u32}, {1_u32, 4_u32}, {0_u32, 1_u32}, {1_u32, 4_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      overflowing: [] of Tokens::Encoding,
      sequence_ranges: {} of UInt64 => Range(UInt64, UInt64)
    ))
  end

  it "trims offsets as a post-processor for single and pair encodings" do
    start = Tokens::Encoding.new(
      ids: Array(UInt32).new(5, 0_u32),
      type_ids: [] of UInt32,
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 1_u32}, {0_u32, 11_u32}, {11_u32, 18_u32}, {18_u32, 25_u32}, {25_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      overflowing: [] of Tokens::Encoding,
      sequence_ranges: {} of UInt64 => Range(UInt64, UInt64)
    )

    expected = Tokens::Encoding.new(
      ids: Array(UInt32).new(5, 0_u32),
      type_ids: Array(UInt32).new(5, 0_u32),
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      overflowing: [] of Tokens::Encoding,
      sequence_ranges: {0_u64 => (0_u64...5_u64)}
    )

    bytelevel = Tokens::PreTokenizers::ByteLevel.default.trim_offsets(true)
    bytelevel.process(start.copy, nil, false).should eq(expected)

    pair_expected = Tokens::Encoding.new(
      ids: Array(UInt32).new(10, 0_u32),
      type_ids: [0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32],
      tokens: ["Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ", "Ġ", "ĠĠĠĠHelloĠĠ", "ĠĠHello", "HelloĠĠ", "ĠĠĠĠ"],
      words: [] of UInt32?,
      offsets: [{0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}, {0_u32, 0_u32}, {4_u32, 9_u32}, {13_u32, 18_u32}, {18_u32, 23_u32}, {29_u32, 29_u32}],
      special_tokens_mask: [] of UInt32,
      attention_mask: [] of UInt32,
      overflowing: [] of Tokens::Encoding,
      sequence_ranges: {0_u64 => (0_u64...5_u64), 1_u64 => (5_u64...10_u64)}
    )

    bytelevel.process(start.copy, start.copy, false).should eq(pair_expected)
  end

  it "keeps unknown characters verbatim during decode" do
    bytelevel = Tokens::PreTokenizers::ByteLevel.default
    bytelevel.decode_chain(["Hello", "Ġthere", "Ġdear", "Ġfriend!", "Ġ", "[PA D]"])
      .should eq(["Hello there dear friend! [PA D]"])
  end

  it "loads legacy and explicit use_regex settings" do
    Tokens::PreTokenizers::ByteLevel.from_json(%({"type":"ByteLevel","add_prefix_space":true,"trim_offsets":false}))
      .use_regex?.should be_true

    Tokens::PreTokenizers::ByteLevel.from_json(%({"type":"ByteLevel","add_prefix_space":true,"trim_offsets":false,"use_regex":true}))
      .use_regex?.should be_true

    Tokens::PreTokenizers::ByteLevel.from_json(%({"type":"ByteLevel","add_prefix_space":true,"trim_offsets":false,"use_regex":false}))
      .use_regex?.should be_false
  end
end
