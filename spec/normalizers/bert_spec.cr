require "../spec_helper"

module Tokens::Normalizers
  describe BertNormalizer do
    it "strips accents when configured" do
      normalizer = BertNormalizer.new(
        clean_text: false,
        handle_chinese_chars: false,
        strip_accents: true,
        lowercase: false,
      )
      normalized = Tokens::NormalizedString.from("Héllò")

      normalizer.normalize(normalized)

      normalized.get.should eq("Hello")
    end

    it "handles chinese chars when configured" do
      normalizer = BertNormalizer.new(
        clean_text: false,
        handle_chinese_chars: true,
        strip_accents: false,
        lowercase: false,
      )
      normalized = Tokens::NormalizedString.from("你好")

      normalizer.normalize(normalized)

      normalized.get.should eq(" 你  好 ")
    end

    it "cleans control-like text when configured" do
      normalizer = BertNormalizer.new(
        clean_text: true,
        handle_chinese_chars: false,
        strip_accents: false,
        lowercase: false,
      )
      normalized = Tokens::NormalizedString.from("\u{feff}Hello")

      normalizer.normalize(normalized)

      normalized.get.should eq("Hello")
    end

    it "lowercases when configured" do
      normalizer = BertNormalizer.new(
        clean_text: false,
        handle_chinese_chars: false,
        strip_accents: false,
        lowercase: true,
      )
      normalized = Tokens::NormalizedString.from("Héllò")

      normalizer.normalize(normalized)

      normalized.get.should eq("héllò")
    end
  end
end
