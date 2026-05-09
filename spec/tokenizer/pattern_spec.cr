require "../spec_helper"

def assert_pattern_matches(inside : String, pattern, expected : Array(Tokens::Pattern::Match))
  pattern.find_matches(inside).should eq(expected)

  inverted = Tokens::Invert.new(pattern).find_matches(inside)
  expected_inverted = expected.map do |(offsets, is_match)|
    {offsets, !is_match}
  end

  inverted.should eq(expected_inverted)
end

describe "pattern" do
  it "char" do
    assert_pattern_matches("aba", 'a', [{ {0_u32, 1_u32}, true }, { {1_u32, 2_u32}, false }, { {2_u32, 3_u32}, true }])
    assert_pattern_matches("bbbba", 'a', [{ {0_u32, 4_u32}, false }, { {4_u32, 5_u32}, true }])
    assert_pattern_matches("aabbb", 'a', [{ {0_u32, 1_u32}, true }, { {1_u32, 2_u32}, true }, { {2_u32, 5_u32}, false }])
    assert_pattern_matches("", 'a', [{ {0_u32, 0_u32}, false }])
    assert_pattern_matches("aaa", 'b', [{ {0_u32, 3_u32}, false }])
  end

  it "str" do
    assert_pattern_matches("aba", "a", [{ {0_u32, 1_u32}, true }, { {1_u32, 2_u32}, false }, { {2_u32, 3_u32}, true }])
    assert_pattern_matches("bbbba", "a", [{ {0_u32, 4_u32}, false }, { {4_u32, 5_u32}, true }])
    assert_pattern_matches("aabbb", "a", [{ {0_u32, 1_u32}, true }, { {1_u32, 2_u32}, true }, { {2_u32, 5_u32}, false }])
    assert_pattern_matches("aabbb", "ab", [{ {0_u32, 1_u32}, false }, { {1_u32, 3_u32}, true }, { {3_u32, 5_u32}, false }])
    assert_pattern_matches("aabbab", "ab", [{ {0_u32, 1_u32}, false }, { {1_u32, 3_u32}, true }, { {3_u32, 4_u32}, false }, { {4_u32, 6_u32}, true }])
    assert_pattern_matches("", "", [{ {0_u32, 0_u32}, false }])
    assert_pattern_matches("aaa", "", [{ {0_u32, 3_u32}, false }])
    assert_pattern_matches("aaa", "b", [{ {0_u32, 3_u32}, false }])
  end

  it "functions" do
    is_b = ->(char : Char) { char == 'b' }

    assert_pattern_matches("aba", is_b, [{ {0_u32, 1_u32}, false }, { {1_u32, 2_u32}, true }, { {2_u32, 3_u32}, false }])
    assert_pattern_matches("aaaab", is_b, [{ {0_u32, 4_u32}, false }, { {4_u32, 5_u32}, true }])
    assert_pattern_matches("bbaaa", is_b, [{ {0_u32, 1_u32}, true }, { {1_u32, 2_u32}, true }, { {2_u32, 5_u32}, false }])
    assert_pattern_matches("", is_b, [{ {0_u32, 0_u32}, false }])
    assert_pattern_matches("aaa", is_b, [{ {0_u32, 3_u32}, false }])
  end

  it "regex" do
    is_whitespace = /\s+/

    assert_pattern_matches("a   b", is_whitespace, [{ {0_u32, 1_u32}, false }, { {1_u32, 4_u32}, true }, { {4_u32, 5_u32}, false }])
    assert_pattern_matches("   a   b   ", is_whitespace, [{ {0_u32, 3_u32}, true }, { {3_u32, 4_u32}, false }, { {4_u32, 7_u32}, true }, { {7_u32, 8_u32}, false }, { {8_u32, 11_u32}, true }])
    assert_pattern_matches("", is_whitespace, [{ {0_u32, 0_u32}, false }])
    assert_pattern_matches("𝔾𝕠𝕠𝕕 𝕞𝕠𝕣𝕟𝕚𝕟𝕘", is_whitespace, [{ {0_u32, 16_u32}, false }, { {16_u32, 17_u32}, true }, { {17_u32, 45_u32}, false }])
    assert_pattern_matches("aaa", is_whitespace, [{ {0_u32, 3_u32}, false }])
  end

  it "sys regex" do
    is_whitespace = Tokens::SysRegex.new("\\s+")

    assert_pattern_matches("a   b", is_whitespace, [{ {0_u32, 1_u32}, false }, { {1_u32, 4_u32}, true }, { {4_u32, 5_u32}, false }])
    assert_pattern_matches("   a   b   ", is_whitespace, [{ {0_u32, 3_u32}, true }, { {3_u32, 4_u32}, false }, { {4_u32, 7_u32}, true }, { {7_u32, 8_u32}, false }, { {8_u32, 11_u32}, true }])
    assert_pattern_matches("", is_whitespace, [{ {0_u32, 0_u32}, false }])
    assert_pattern_matches("𝔾𝕠𝕠𝕕 𝕞𝕠𝕣𝕟𝕚𝕟𝕘", is_whitespace, [{ {0_u32, 16_u32}, false }, { {16_u32, 17_u32}, true }, { {17_u32, 45_u32}, false }])
    assert_pattern_matches("aaa", is_whitespace, [{ {0_u32, 3_u32}, false }])
  end
end
