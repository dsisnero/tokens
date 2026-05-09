require "../spec_helper"

module Tokens::Normalizers
  describe Precompiled do
    it "supports expansion followed by removal in one transform pass" do
      transformations = [] of Tuple(Char, Int32)
      normalized = Tokens::NormalizedString.from("™\u{1e}g")

      Precompiled.replace(transformations, "™", "TM")
      Precompiled.replace(transformations, "\u{1e}", "")
      transformations << {'g', 0}

      normalized.transform(transformations, 0)

      normalized.get.should eq("TMg")
    end
  end
end
