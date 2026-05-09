require "../spec_helper"

module Tokens::Normalizers
  describe StripAccents do
    it "strips accents without changing ascii or chinese text" do
      original = "Me llamó".unicode_normalize(:nfkd)
      normalized = Tokens::NormalizedString.from(original)
      StripAccents.new.normalize(normalized)
      normalized.get.should eq("Me llamo")

      ascii = Tokens::NormalizedString.from("Me llamo")
      StripAccents.new.normalize(ascii)
      ascii.get.should eq("Me llamo")

      chinese = Tokens::NormalizedString.from("这很简单".unicode_normalize(:nfkd))
      StripAccents.new.normalize(chinese)
      chinese.get.should eq("这很简单")
    end

    it "handles vietnamese accent stripping" do
      normalized = Tokens::NormalizedString.from("ậ…")
      NFKD.new.normalize(normalized)
      StripAccents.new.normalize(normalized)
      Lowercase.new.normalize(normalized)
      normalized.get.should eq("a...")

      longer = Tokens::NormalizedString.from("Cụ thể, bạn sẽ tham gia một nhóm các giám đốc điều hành tổ chức, các nhà lãnh đạo doanh nghiệp, các học giả, chuyên gia phát triển và tình nguyện viên riêng biệt trong lĩnh vực phi lợi nhuận…")
      NFKD.new.normalize(longer)
      StripAccents.new.normalize(longer)
      Lowercase.new.normalize(longer)
      longer.get.should eq("cu the, ban se tham gia mot nhom cac giam đoc đieu hanh to chuc, cac nha lanh đao doanh nghiep, cac hoc gia, chuyen gia phat trien va tinh nguyen vien rieng biet trong linh vuc phi loi nhuan...")
    end

    it "handles thai accent stripping" do
      normalized = Tokens::NormalizedString.from("ำน\u{e49}ำ3ลำ")
      NFKD.new.normalize(normalized)
      StripAccents.new.normalize(normalized)
      Lowercase.new.normalize(normalized)
      normalized.get.should eq("านา3ลา")
    end

    it "keeps alignments when multiple combining marks are removed" do
      original = "e\u{304}\u{304}\u{304}o"
      normalized = Tokens::NormalizedString.from(original)
      StripAccents.new.normalize(normalized)

      normalized.get.should eq("eo")
      normalized.alignments.should eq([
        {0_u32, 1_u32},
        {7_u32, 8_u32},
      ])
      normalized.alignments_original.should eq([
        {0_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 1_u32},
        {1_u32, 2_u32},
      ])
    end
  end
end
