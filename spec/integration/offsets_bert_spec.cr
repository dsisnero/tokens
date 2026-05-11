require "../spec_helper"

# Helper: create a BERT WordPiece tokenizer matching upstream get_bert
private def get_bert : Tokens::TokenizerImpl
  vocab = Tokens::Models::WordPiece.read_file("data/bert-base-uncased-vocab.txt")
  wp = Tokens::Models::WordPiece.build(vocab: vocab)
  tokenizer = Tokens::TokenizerImpl.new(wp)
  tokenizer.with_normalizer(Tokens::NormalizerWrapper.from(
    Tokens::Normalizers::BertNormalizer.new
  ))
  tokenizer.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
    Tokens::PreTokenizers::BertPreTokenizer.new
  ))
  tokenizer.with_decoder(Tokens::DecoderWrapper.from(
    Tokens::Decoders::WordPiece.default
  ))

  sep_id = tokenizer.token_to_id("[SEP]") || 102_u32
  cls_id = tokenizer.token_to_id("[CLS]") || 101_u32

  tokenizer.with_post_processor(Tokens::PostProcessorWrapper.from(
    Tokens::PostProcessors::BertProcessing.new(
      {"[SEP]", sep_id},
      {"[CLS]", cls_id},
    )
  ))
  tokenizer
end

describe "Offsets - remaining integration tests" do
  it "split_on_added_tokens_bert" do
    input = "Yesterday I saw a [MASK] far away"
    tokenizer = get_bert
    tokenizer.add_special_tokens([Tokens::AddedToken.from("[MASK]", true)])

    output = tokenizer.encode(input, false)

    output.offsets.should eq([
      {0_u32, 9_u32}, {10_u32, 11_u32}, {12_u32, 15_u32},
      {16_u32, 17_u32}, {18_u32, 24_u32}, {25_u32, 28_u32}, {29_u32, 33_u32},
    ])
    output.tokens.should eq(["yesterday", "i", "saw", "a", "[MASK]", "far", "away"])
    output.words.should eq([0_u32, 1_u32, 2_u32, 3_u32, 4_u32, 5_u32, 6_u32])
  end
end
