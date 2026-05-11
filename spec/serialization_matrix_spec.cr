require "./spec_helper"

describe "Serialization matrix tests" do
  it "normalizer round-trip: NFC wrapper" do
    nfc = Tokens::NormalizerWrapper.from(Tokens::Normalizers::NFC.new)
    nfc_ser = nfc.to_json
    nfc_ser.should eq(%({"type":"NFC"}))

    # Wrapper can deserialize from itself
    wrapped = Tokens::NormalizerWrapper.from_json(nfc_ser)
    wrapped.to_json.should eq(nfc_ser)
  end

  it "normalizer round-trip: BertNormalizer wrapper" do
    bert = Tokens::NormalizerWrapper.from(Tokens::Normalizers::BertNormalizer.new)
    bert_ser = bert.to_json
    bert_ser.should eq(%({"type":"BertNormalizer","clean_text":true,"handle_chinese_chars":true,"strip_accents":null,"lowercase":true}))

    # Wrapper can deserialize from itself
    wrapped = Tokens::NormalizerWrapper.from_json(bert_ser)
    wrapped.to_json.should eq(bert_ser)
  end

  it "processor round-trip: BertProcessing wrapper" do
    bert = Tokens::PostProcessorWrapper.from(
      Tokens::PostProcessors::BertProcessing.new({"[SEP]", 0_u32}, {"[CLS]", 0_u32})
    )
    bert_ser = bert.to_json
    bert_ser.should eq(%({"type":"BertProcessing","sep":["[SEP]",0],"cls":["[CLS]",0]}))

    # Wrapper can deserialize from itself
    wrapped = Tokens::PostProcessorWrapper.from_json(bert_ser)
    wrapped.to_json.should eq(bert_ser)
  end

  it "pretokenizer round-trip: BertPreTokenizer wrapper" do
    pretok = Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::BertPreTokenizer.new)
    pretok_ser = pretok.to_json
    pretok_ser.should eq(%({"type":"BertPreTokenizer"}))

    wrapped = Tokens::PreTokenizerWrapper.from_json(pretok_ser)
    wrapped.to_json.should eq(pretok_ser)
  end

  it "pretokenizer round-trip: CharDelimiterSplit wrapper" do
    pretok = Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::CharDelimiterSplit.new(' '))
    pretok_ser = pretok.to_json
    pretok_ser.should eq(%({"type":"Delimiter","delimiter":" "}))

    wrapped = Tokens::PreTokenizerWrapper.from_json(pretok_ser)
    wrapped.to_json.should eq(pretok_ser)
  end

  it "pretokenizer round-trip: Whitespace wrapper" do
    pretok = Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::Whitespace.new)
    pretok_ser = pretok.to_json
    pretok_ser.should eq(%({"type":"Whitespace"}))

    wrapped = Tokens::PreTokenizerWrapper.from_json(pretok_ser)
    wrapped.to_json.should eq(pretok_ser)
  end

  it "pretokenizer round-trip: Split with String pattern" do
    pretok = Tokens::PreTokenizers::Split.new(
      Tokens::PreTokenizers::SplitPattern.new("[SEP]", Tokens::PreTokenizers::SplitPattern::Kind::String),
      Tokens::SplitDelimiterBehavior::Isolated,
      false
    )
    pretok_ser = pretok.to_json
    pretok_ser.should eq(%({"type":"Split","pattern":{"String":"[SEP]"},"behavior":"Isolated","invert":false}))
    Tokens::PreTokenizers::Split.from_json(pretok_ser).should eq(pretok)
  end

  it "pretokenizer round-trip: Split with Regex pattern" do
    pretok = Tokens::PreTokenizers::Split.new(
      Tokens::PreTokenizers::SplitPattern.new("[SEP]", Tokens::PreTokenizers::SplitPattern::Kind::Regex),
      Tokens::SplitDelimiterBehavior::Isolated,
      false
    )
    pretok_ser = pretok.to_json
    pretok_ser.should eq(%({"type":"Split","pattern":{"Regex":"[SEP]"},"behavior":"Isolated","invert":false}))
    Tokens::PreTokenizers::Split.from_json(pretok_ser).should eq(pretok)
  end

  it "decoder round-trip: ByteLevel wrapper" do
    bl = Tokens::DecoderWrapper.from(Tokens::PreTokenizers::ByteLevel.default)
    bl_ser = bl.to_json
    bl_ser.should eq(%({"type":"ByteLevel","add_prefix_space":true,"trim_offsets":true,"use_regex":true}))

    wrapped = Tokens::DecoderWrapper.from_json(bl_ser)
    wrapped.to_json.should eq(bl_ser)
  end

  it "model round-trip: BPE wrapper" do
    bpe = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[]}))
    bpe_ser = bpe.to_json
    wrapped = Tokens::ModelWrapper.from_json(bpe_ser)
    wrapped.to_json.should eq(bpe_ser)
  end

  it "tokenizer round-trip: WordPiece + NFC" do
    wp = Tokens::Models::WordPiece.default
    tokenizer = Tokens::TokenizerImpl.new(wp)
    tokenizer.with_normalizer(Tokens::NormalizerWrapper.from(Tokens::Normalizers::NFC.new))

    ser = tokenizer.to_json
    restored = Tokens::TokenizerImpl.from_json(ser)
    restored.to_json.should eq(ser)
  end

  it "BPE dropout serde" do
    bpe = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[]}))
    ser = bpe.to_json
    deser = Tokens::Models::BPE::BPE.from_json(ser)
    deser.should eq(bpe)

    bpe2 = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[],"dropout":0.1}))
    d = bpe2.dropout.should_not be_nil
    (d - 0.1).abs.should be < 0.001

    # dropout=0.0 should be treated as Some(0.0)
    bpe3 = Tokens::Models::BPE::BPE.from_json(%({"type":"BPE","vocab":{},"merges":[],"dropout":0.0}))
    d3 = bpe3.dropout.should_not be_nil
    d3.should eq(0.0)
  end
end
