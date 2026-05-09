require "../spec_helper"

private def assert_normalized_string(
  value : Tokens::NormalizedString,
  normalized : String,
  alignments : Array(Tuple(UInt32, UInt32)),
  original : String,
)
  value.normalized.should eq(normalized)
  value.alignments.should eq(alignments)
  value.original.should eq(original)
end

describe Tokens::NormalizedString do
  it "computes range lengths" do
    Tokens::Range::Original.new(3..7).len.should eq(5)
    Tokens::Range::Original.new(3...7).len.should eq(4)
  end

  it "tracks added chars from nfd" do
    normalized = Tokens::NormalizedString.from("élégant")
    normalized.nfd

    normalized.alignments.should eq([
      {0_u32, 2_u32},
      {0_u32, 2_u32},
      {0_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 5_u32},
      {3_u32, 5_u32},
      {3_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
    ])
    normalized.alignments_original.should eq([
      {0_u32, 3_u32},
      {0_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 7_u32},
      {4_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
    ])
  end

  it "removes chars added by nfd" do
    normalized = Tokens::NormalizedString.from("élégant")
    normalized.nfd.filter { |char| !Unicode.mark?(char) }

    normalized.get.should eq("elegant")
    normalized.alignments.should eq([
      {0_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
    ])
  end

  it "removes chars from normalized strings" do
    normalized = Tokens::NormalizedString.from("élégant")
    normalized.filter { |char| char != 'n' }

    normalized.get.should eq("élégat")
    normalized.alignments.should eq([
      {0_u32, 2_u32},
      {0_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 5_u32},
      {3_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {8_u32, 9_u32},
    ])
  end

  it "handles mixed addition and removal" do
    normalized = Tokens::NormalizedString.from("élégant")
    normalized.nfd.filter { |char| !Unicode.mark?(char) && char != 'n' }

    normalized.get.should eq("elegat")
    normalized.alignments.should eq([
      {0_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {8_u32, 9_u32},
    ])
  end

  it "converts ranges between original and normalized offsets" do
    normalized = Tokens::NormalizedString.from("    __Hello__   ")
    normalized.filter { |char| !char.whitespace? }.lowercase

    hello_range = normalized.convert_offsets(Tokens::Range::Original.new(6...11))
    hello_range.should eq(2...7)
    normalized.get_range(Tokens::Range::Normalized.new(hello_range.not_nil!)).should eq("hello")
    normalized.get_range_original(Tokens::Range::Normalized.new(hello_range.not_nil!)).should eq("Hello")
    normalized.get_range(Tokens::Range::Original.new(6...11)).should eq("hello")
    normalized.get_range_original(Tokens::Range::Original.new(6...11)).should eq("Hello")
  end

  it "recovers original ranges from normalized spans" do
    normalized = Tokens::NormalizedString.from("Hello_______ World!")
    normalized.filter { |char| char != '_' }.lowercase

    world_normalized = normalized.get_range(Tokens::Range::Normalized.new(6...11))
    world_original = normalized.get_range_original(Tokens::Range::Normalized.new(6...11))
    world_normalized.should eq("world")
    world_original.should eq("World")

    original_range = Tokens::Range::Original.new(normalized.convert_offsets(Tokens::Range::Normalized.new(6...11)).not_nil!)
    normalized.get_range(original_range).should eq("world")
    normalized.get_range_original(original_range).should eq("World")
    original_range.into_full_range(normalized.len_original).should eq(13...18)
  end

  it "preserves original offsets when adding around edges" do
    normalized = Tokens::NormalizedString.from("Hello")
    normalized.transform([
      {' ', 1},
      {'H', 0},
      {'e', 0},
      {'l', 0},
      {'l', 0},
      {'o', 0},
      {' ', 1},
    ], 0)

    normalized.normalized.should eq(" Hello ")
    normalized.get_range_original(Tokens::Range::Normalized.new(1...(normalized.normalized.bytesize - 1))).should eq("Hello")
  end

  it "tracks inserted character alignment" do
    normalized = Tokens::NormalizedString.from("野口 No")
    normalized.transform(
      normalized.get.each_char.flat_map { |char|
        if char.ord > 0x4E00
          [{' ', 0}, {char, 1}, {' ', 1}]
        else
          [{char, 0}]
        end
      }.to_a,
      0
    )

    assert_normalized_string(
      normalized,
      " 野  口  No",
      [
        {0_u32, 3_u32},
        {0_u32, 3_u32},
        {0_u32, 3_u32},
        {0_u32, 3_u32},
        {0_u32, 3_u32},
        {3_u32, 6_u32},
        {3_u32, 6_u32},
        {3_u32, 6_u32},
        {3_u32, 6_u32},
        {3_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
      ],
      "野口 No"
    )
  end

  it "maps normalized offsets after removing leading chars" do
    normalized = Tokens::NormalizedString.from("     Hello")
    normalized.filter { |char| !char.whitespace? }

    normalized.get_range_original(Tokens::Range::Normalized.new(1..."Hello".bytesize)).should eq("ello")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("Hello")
  end

  it "maps normalized offsets after removing trailing chars" do
    normalized = Tokens::NormalizedString.from("Hello    ")
    normalized.filter { |char| !char.whitespace? }

    normalized.get_range_original(Tokens::Range::Normalized.new(0...4)).should eq("Hell")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("Hello")
  end

  it "maps normalized offsets after trimming both edges" do
    normalized = Tokens::NormalizedString.from("  Hello  ")
    normalized.filter { |char| !char.whitespace? }

    normalized.normalized.should eq("Hello")
    normalized.get_range_original(Tokens::Range::Normalized.new(0..."Hello".bytesize)).should eq("Hello")
    normalized.get_range_original(Tokens::Range::Normalized.new(1..."Hell".bytesize)).should eq("ell")
  end

  it "strips leading and trailing whitespace" do
    normalized = Tokens::NormalizedString.from("  This is an example  ")
    normalized.strip

    normalized.normalized.should eq("This is an example")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("This is an example")
  end

  it "strips leading whitespace only" do
    normalized = Tokens::NormalizedString.from("  This is an example  ")
    normalized.lstrip

    normalized.normalized.should eq("This is an example  ")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("This is an example  ")
  end

  it "strips trailing whitespace only" do
    normalized = Tokens::NormalizedString.from("  This is an example  ")
    normalized.rstrip

    normalized.normalized.should eq("  This is an example")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("  This is an example")
  end

  it "strips unicode whitespace" do
    normalized = Tokens::NormalizedString.from("  你好asa \n")
    normalized.strip

    normalized.normalized.should eq("你好asa")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...normalized.normalized.bytesize)).should eq("你好asa")
  end

  it "prepends text with first-char alignment" do
    normalized = Tokens::NormalizedString.from("there")
    normalized.prepend("Hey ")

    assert_normalized_string(
      normalized,
      "Hey there",
      [
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
      ],
      "there"
    )
    normalized.convert_offsets(Tokens::Range::Normalized.new(0...4)).should eq(0...1)
  end

  it "appends text with last-char alignment" do
    normalized = Tokens::NormalizedString.from("Hey")
    normalized.append(" there")

    assert_normalized_string(
      normalized,
      "Hey there",
      [
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
        {2_u32, 3_u32},
      ],
      "Hey"
    )
    normalized.convert_offsets(Tokens::Range::Normalized.new(3..." there".bytesize)).should eq(2...3)
  end

  it "gets character-based ranges from plain strings" do
    source = "Hello my name is John 👋"
    Tokens.get_range_of(source, ..).should eq(source)
    Tokens.get_range_of(source, 17..).should eq("John 👋")
  end

  it "slices and preserves alignment" do
    normalized = Tokens::NormalizedString.from("𝔾𝕠𝕠𝕕 𝕞𝕠𝕣𝕟𝕚𝕟𝕘")
    normalized.nfkc

    original_slice = normalized.slice(Tokens::Range::Original.new(0...4))
    original_slice.not_nil!.get.should eq("G")
    original_slice.not_nil!.get_original.should eq("𝔾")

    normalized_slice = normalized.slice(Tokens::Range::Normalized.new(0...4))
    normalized_slice.not_nil!.get.should eq("Good")
    normalized_slice.not_nil!.get_original.should eq("𝔾𝕠𝕠𝕕")
  end

  it "replaces chars, strings, and regex matches" do
    normalized = Tokens::NormalizedString.from(" Hello   friend ")
    normalized.replace(' ', "_")
    normalized.get.should eq("_Hello___friend_")

    overlapping = Tokens::NormalizedString.from("aaaab")
    overlapping.replace("aaa", "b")
    overlapping.get.should eq("bab")

    regex = Tokens::NormalizedString.from(" Hello   friend ")
    regex.replace(/\s+/, "_")
    regex.get.should eq("_Hello_friend_")
  end

  it "splits using all delimiter behaviors" do
    normalized = Tokens::NormalizedString.from("The-final--countdown")

    normalized.split('-', Tokens::SplitDelimiterBehavior::Removed).map(&.get).should eq(["The", "final", "countdown"])
    normalized.split('-', Tokens::SplitDelimiterBehavior::Isolated).map(&.get).should eq(["The", "-", "final", "-", "-", "countdown"])
    normalized.split('-', Tokens::SplitDelimiterBehavior::MergedWithPrevious).map(&.get).should eq(["The-", "final-", "-", "countdown"])
    normalized.split('-', Tokens::SplitDelimiterBehavior::MergedWithNext).map(&.get).should eq(["The", "-final", "-", "-countdown"])
    normalized.split('-', Tokens::SplitDelimiterBehavior::Contiguous).map(&.get).should eq(["The", "-", "final", "--", "countdown"])
  end

  it "supports append after clear" do
    normalized = Tokens::NormalizedString.from("Hello")
    normalized.clear
    normalized.append(" World")

    normalized.get.should eq(" World")
    normalized.len_original.should eq(5)
    normalized.length.should eq(6)
    normalized.get_range_original(Tokens::Range::Original.new(0...5)).should eq("Hello")
    normalized.get_range_original(Tokens::Range::Normalized.new(0...6)).should eq("")
    normalized.get_range(Tokens::Range::Normalized.new(0...6)).should eq(" World")
  end

  it "keeps transform and normalization composition stable" do
    normalized = Tokens::NormalizedString.from("abc…")
    normalized.nfkd
    normalized.transform([
      {'a', -2},
      {'.', 0},
      {'.', 0},
      {'.', 0},
    ], 0)
    normalized.lowercase

    normalized.get.should eq("a...")
  end

  it "transforms single-byte ranges with alignment parity" do
    source = Tokens::NormalizedString.from("Hello friend")

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...4), [{'Y', 0}], 3)
    assert_normalized_string(
      current,
      "Yo friend",
      [
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 0_u32},
      {0_u32, 0_u32},
      {0_u32, 0_u32},
      {0_u32, 1_u32},
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(3...10), [{'_', 0}, {'F', 0}, {'R', -2}], 2)
    assert_normalized_string(
      current,
      "Hel_FRnd",
      [
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 1_u32},
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 3_u32},
      {3_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 6_u32},
      {6_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(5..), [{'_', 0}, {'F', -5}], 0)
    assert_normalized_string(
      current,
      "Hello_F",
      [
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 1_u32},
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 7_u32},
      {7_u32, 7_u32},
      {7_u32, 7_u32},
      {7_u32, 7_u32},
      {7_u32, 7_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...1), [{'H', 1}, {'H', 0}], 0)
    assert_normalized_string(
      current,
      "HHello friend",
      [
        {0_u32, 0_u32},
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
      {11_u32, 12_u32},
      {12_u32, 13_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...0), [{'H', 1}], 0)
    assert_normalized_string(
      current,
      "HHello friend",
      [
        {0_u32, 0_u32},
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
      {11_u32, 12_u32},
      {12_u32, 13_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...1), [{'H', 0}, {'H', 1}], 0)
    assert_normalized_string(
      current,
      "HHello friend",
      [
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
      {11_u32, 12_u32},
      {12_u32, 13_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(5...6), [{'_', 0}, {'m', 1}, {'y', 1}, {'_', 1}], 0)
    assert_normalized_string(
      current,
      "Hello_my_friend",
      [
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {5_u32, 6_u32},
        {5_u32, 6_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 1_u32},
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
      {11_u32, 12_u32},
      {12_u32, 13_u32},
      {13_u32, 14_u32},
      {14_u32, 15_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(11..), [{'d', 0}, {'_', 1}, {'!', 1}], 0)
    assert_normalized_string(
      current,
      "Hello friend_!",
      [
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
        {8_u32, 9_u32},
        {9_u32, 10_u32},
        {10_u32, 11_u32},
        {11_u32, 12_u32},
        {11_u32, 12_u32},
        {11_u32, 12_u32},
      ],
      "Hello friend"
    )
    current.alignments_original.should eq([
      {0_u32, 1_u32},
      {1_u32, 2_u32},
      {2_u32, 3_u32},
      {3_u32, 4_u32},
      {4_u32, 5_u32},
      {5_u32, 6_u32},
      {6_u32, 7_u32},
      {7_u32, 8_u32},
      {8_u32, 9_u32},
      {9_u32, 10_u32},
      {10_u32, 11_u32},
      {11_u32, 14_u32},
    ])
  end

  it "transforms multi-byte ranges with alignment parity" do
    source = Tokens::NormalizedString.from("𝔾𝕠𝕠𝕕")

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...8), [{'G', -1}], 0)
    assert_normalized_string(
      current,
      "G𝕠𝕕",
      [
        {0_u32, 4_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {0_u32, 1_u32},
      {0_u32, 1_u32},
      {0_u32, 1_u32},
      {0_u32, 1_u32},
      {1_u32, 1_u32},
      {1_u32, 1_u32},
      {1_u32, 1_u32},
      {1_u32, 1_u32},
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
    ])
    current.get_range(Tokens::Range::Original.new(0...8)).should eq("G")
    current.get_range(Tokens::Range::Original.new(0...4)).should eq("G")
    current.get_range_original(Tokens::Range::Original.new(0...4)).should eq("𝔾")
    current.get_range_original(Tokens::Range::Original.new(0...8)).should eq("𝔾𝕠")

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(4...12), [{'o', -1}], 0)
    assert_normalized_string(
      current,
      "𝔾o𝕕",
      [
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {4_u32, 5_u32},
      {4_u32, 5_u32},
      {4_u32, 5_u32},
      {4_u32, 5_u32},
      {5_u32, 5_u32},
      {5_u32, 5_u32},
      {5_u32, 5_u32},
      {5_u32, 5_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(12..), [{'d', 0}, {'!', 1}], 0)
    assert_normalized_string(
      current,
      "𝔾𝕠𝕠d!",
      [
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...4), [{'_', 1}, {'𝔾', 0}], 0)
    assert_normalized_string(
      current,
      "_𝔾𝕠𝕠𝕕",
      [
        {0_u32, 0_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {1_u32, 5_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
    ])
    current.get_range(Tokens::Range::Original.new(0...8)).should eq("𝔾𝕠")
    current.get_range(Tokens::Range::Original.new(0...4)).should eq("𝔾")
    current.get_range_original(Tokens::Range::Original.new(0...4)).should eq("𝔾")
    current.get_range_original(Tokens::Range::Original.new(0...8)).should eq("𝔾𝕠")

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...0), [{'_', 1}], 0)
    assert_normalized_string(
      current,
      "_𝔾𝕠𝕠𝕕",
      [
        {0_u32, 0_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(0...4), [{'𝔾', 0}, {'o', 1}], 0)
    assert_normalized_string(
      current,
      "𝔾o𝕠𝕠𝕕",
      [
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {0_u32, 5_u32},
      {0_u32, 5_u32},
      {0_u32, 5_u32},
      {0_u32, 5_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {5_u32, 9_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {9_u32, 13_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
      {13_u32, 17_u32},
    ])
    current.get_range(Tokens::Range::Original.new(0...8)).should eq("𝔾o𝕠")
    current.get_range(Tokens::Range::Original.new(0...4)).should eq("𝔾o")
    current.get_range_original(Tokens::Range::Original.new(0...4)).should eq("𝔾")
    current.get_range_original(Tokens::Range::Original.new(0...8)).should eq("𝔾𝕠")

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(4...8), [{'𝕠', 0}, {'o', 1}, {'o', 1}, {'o', 1}], 0)
    assert_normalized_string(
      current,
      "𝔾𝕠ooo𝕠𝕕",
      [
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {4_u32, 11_u32},
      {4_u32, 11_u32},
      {4_u32, 11_u32},
      {4_u32, 11_u32},
      {11_u32, 15_u32},
      {11_u32, 15_u32},
      {11_u32, 15_u32},
      {11_u32, 15_u32},
      {15_u32, 19_u32},
      {15_u32, 19_u32},
      {15_u32, 19_u32},
      {15_u32, 19_u32},
    ])

    current = source.dup
    current.transform_range(Tokens::Range::Original.new(16..), [{'!', 1}], 0)
    assert_normalized_string(
      current,
      "𝔾𝕠𝕠𝕕!",
      [
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {0_u32, 4_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {4_u32, 8_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {8_u32, 12_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
        {12_u32, 16_u32},
      ],
      "𝔾𝕠𝕠𝕕"
    )
    current.alignments_original.should eq([
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {0_u32, 4_u32},
      {4_u32, 8_u32},
      {4_u32, 8_u32},
      {4_u32, 8_u32},
      {4_u32, 8_u32},
      {8_u32, 12_u32},
      {8_u32, 12_u32},
      {8_u32, 12_u32},
      {8_u32, 12_u32},
      {12_u32, 17_u32},
      {12_u32, 17_u32},
      {12_u32, 17_u32},
      {12_u32, 17_u32},
    ])
  end
end
