require "../spec_helper"

def get_padding_encodings
  [
    Tokens::Encoding.new(ids: [0_u32, 1_u32, 2_u32, 3_u32, 4_u32]),
    Tokens::Encoding.new(ids: [0_u32, 1_u32, 2_u32]),
  ]
end

module Tokens
  describe "padding" do
    it "pads to the requested multiple" do
      encodings = get_padding_encodings
      params = PaddingParams.new(
        strategy: PaddingStrategy::Fixed,
        direction: PaddingDirection::Right,
        pad_to_multiple_of: 8_u64,
        fixed_size: 7_u64
      )

      Tokens.pad_encodings(encodings, params)

      encodings.all?(&.ids.size.==(8)).should be_true

      encodings = get_padding_encodings
      params = PaddingParams.new(
        strategy: PaddingStrategy::BatchLongest,
        direction: PaddingDirection::Right,
        pad_to_multiple_of: 6_u64
      )

      Tokens.pad_encodings(encodings, params)

      encodings.all?(&.ids.size.==(6)).should be_true

      params = PaddingParams.new(
        strategy: PaddingStrategy::BatchLongest,
        direction: PaddingDirection::Right,
        pad_to_multiple_of: 0_u64
      )

      Tokens.pad_encodings(encodings, params)
    end
  end
end
