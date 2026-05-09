require "../spec_helper"

module Tokens::Normalizers
  describe NFKC do
    it "normalizes compatibility forms" do
      original = "\u{fb01}"
      normalized = "fi"

      current = Tokens::NormalizedString.from(original)
      NFKC.new.normalize(current)

      current.get.should eq(normalized)
      current.alignments.should eq([
        {0_u32, 3_u32},
        {0_u32, 3_u32},
      ])
      current.alignments_original.should eq([
        {0_u32, 2_u32},
        {0_u32, 2_u32},
        {0_u32, 2_u32},
      ])
    end
  end
end
