require "../spec_helper"

module Tokens::Normalizers
  describe Prepend do
    it "prepends text while preserving alignments" do
      original = "Hello"
      normalized = "▁Hello"

      current = Tokens::NormalizedString.from(original)
      Prepend.new("▁").normalize(current)

      current.get.should eq(normalized)
      current.alignments.should eq([
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {0_u32, 1_u32},
        {1_u32, 2_u32},
        {2_u32, 3_u32},
        {3_u32, 4_u32},
        {4_u32, 5_u32},
      ])
      current.alignments_original.should eq([
        {0_u32, 4_u32},
        {4_u32, 5_u32},
        {5_u32, 6_u32},
        {6_u32, 7_u32},
        {7_u32, 8_u32},
      ])
    end
  end
end
