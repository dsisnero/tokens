require "../spec_helper"

module Tokens::Normalizers
  describe Replace do
    it "replaces plain string matches" do
      original = "This is a ''test''"
      normalized = "This is a \"test\""

      current = Tokens::NormalizedString.from(original)
      Replace.new("''", "\"").normalize(current)

      current.get.should eq(normalized)
    end

    it "replaces regex matches" do
      original = "This     is   a         test"
      normalized = "This is a test"

      current = Tokens::NormalizedString.from(original)
      Replace.new(ReplacePattern.regex("\\s+"), ' ').normalize(current)

      current.get.should eq(normalized)
    end

    it "serializes and deserializes" do
      replace = Replace.new("Hello", "Hey")
      replace_s = %({"type":"Replace","pattern":{"String":"Hello"},"content":"Hey"})
      replace.to_json.should eq(replace_s)
      Replace.from_json(replace_s).should eq(replace)

      replace = Replace.new(ReplacePattern.regex("\\s+"), ' ')
      replace_s = %({"type":"Replace","pattern":{"Regex":"\\\\s+"},"content":" "})
      replace.to_json.should eq(replace_s)
      Replace.from_json(replace_s).should eq(replace)
    end

    it "replaces while decoding" do
      Replace.new("_", " ").decode_chain(["hello", "_hello"]).should eq(["hello", " hello"])
    end
  end
end
