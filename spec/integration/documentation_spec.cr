require "../spec_helper"

describe "Documentation integration tests" do
  it "load_tokenizer (roberta)" do
    json = File.read("data/roberta.json")
    tokenizer = Tokens::TokenizerImpl.from_json(json)

    example = "This is an example"
    encoding = tokenizer.encode(example, false)

    encoding.ids.should eq([713_u32, 16_u32, 41_u32, 1246_u32])
    encoding.tokens.should eq(["This", "Ġis", "Ġan", "Ġexample"])

    decoded = tokenizer.decode(encoding.ids, false)
    decoded.should eq(example)
  end

  it "streaming_tokenizer" do
    tokenizer = Tokens::TokenizerImpl.from_json(File.read("data/roberta.json"))

    stream = tokenizer.decode_stream(false)
    stream.step(713_u32).should eq("This")
    stream.step(16_u32).should eq(" is")
    stream.step(41_u32).should eq(" an")
    stream.step(1246_u32).should eq(" example")

    # Albert tokenizer
    t2 = Tokens::TokenizerImpl.from_json(File.read("data/albert-base-v1-tokenizer.json"))
    encoded = t2.encode("This is an example", false)
    encoded.ids.should eq([48_u32, 25_u32, 40_u32, 823_u32])

    stream2 = t2.decode_stream(false)
    # No space with albert - first token without leading space
    stream2.step(25_u32).should eq("is")
    stream2 = t2.decode_stream(false)
    stream2.step(48_u32).should eq("this")
    stream2.step(25_u32).should eq(" is")
    stream2.step(40_u32).should eq(" an")
    stream2.step(823_u32).should eq(" example")
  end

  it "train_tokenizer" do
    vocab_size = 100
    model = Tokens::Models::BPE::BpeBuilder.new.build
    tokenizer = Tokens::TokenizerImpl.new(model)

    tokenizer.with_normalizer(
      Tokens::Normalizers::Sequence.new([
        Tokens::Normalizers::Strip.new(true, true),
        Tokens::Normalizers::NFC.new,
      ])
    )
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::ByteLevel.default)
    tokenizer.with_post_processor(Tokens::PreTokenizers::ByteLevel.default)
    tokenizer.with_decoder(Tokens::PreTokenizers::ByteLevel.default)

    trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
      .show_progress(false)
      .vocab_size(vocab_size)
      .min_frequency(0_u64)
      .special_tokens([
        Tokens::AddedToken.new("<s>".to_s, true),
        Tokens::AddedToken.new("<pad>".to_s, true),
        Tokens::AddedToken.new("</s>".to_s, true),
        Tokens::AddedToken.new("<unk>".to_s, true),
        Tokens::AddedToken.new("<mask>".to_s, true),
      ])
      .build

    tokenizer.train_from_files(trainer, ["data/small.txt"])
    tokenizer.get_vocab_size(true).should be >= vocab_size
  end

  it "quicktour" do
    json_str = File.read("data/tokenizer-wiki.json")
    tokenizer = Tokens::TokenizerImpl.from_json(json_str)

    output = tokenizer.encode("Hello, y'all! How are you \u{1F601} ?", true)

    output.tokens.should eq(["Hello", ",", "y", "'", "all", "!", "How", "are", "you", "[UNK]", "?"])
    output.ids.should eq([27253_u32, 16_u32, 93_u32, 11_u32, 5097_u32, 5_u32, 7961_u32, 5112_u32, 6218_u32, 0_u32, 35_u32])
    output.offsets[9].should eq({26_u32, 30_u32})

    tokenizer.token_to_id("[SEP]").should eq(2_u32)

    # Configure TemplateProcessing post-processor
    special_tokens = Tokens::PostProcessors::TokensMap.from_tuples([
      {"[CLS]", tokenizer.token_to_id("[CLS]").not_nil!},
      {"[SEP]", tokenizer.token_to_id("[SEP]").not_nil!},
    ])
    tokenizer.with_post_processor(
      Tokens::PostProcessors::TemplateProcessing.build(
        Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP]"),
        Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP] $B:1 [SEP]:1"),
        special_tokens,
      )
    )

    output = tokenizer.encode("Hello, y'all! How are you \u{1F601} ?", true)
    output.tokens.should eq(["[CLS]", "Hello", ",", "y", "'", "all", "!", "How", "are", "you", "[UNK]", "?", "[SEP]"])

    # Pair encoding
    output = tokenizer.encode({"Hello, y'all!", "How are you \u{1F601} ?"}, true)
    output.tokens.should eq([
      "[CLS]", "Hello", ",", "y", "'", "all", "!", "[SEP]", "How", "are", "you", "[UNK]",
      "?", "[SEP]",
    ])
    output.type_ids.should eq([0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 0_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32])

    # Batch encoding (no padding)
    output = tokenizer.encode_batch(["Hello, y'all!", "How are you \u{1F601} ?"], true)
    output.size.should eq(2)

    # Batch encoding pairs
    output = tokenizer.encode_batch([
      {"Hello, y'all!", "How are you \u{1F601} ?"},
      {"Hello to you too!", "I'm fine, thank you!"},
    ], true)
    output.size.should eq(2)

    # Padding
    tokenizer.with_padding(Tokens::PaddingParams.new(pad_id: 3_u32, pad_token: "[PAD]"))
    output = tokenizer.encode_batch(["Hello, y'all!", "How are you \u{1F601} ?"], true)
    output[1].tokens.should eq(["[CLS]", "How", "are", "you", "[UNK]", "?", "[SEP]", "[PAD]"])
    output[1].attention_mask.should eq([1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32, 0_u32])
  end

  it "pipeline" do
    json_str = File.read("data/tokenizer-wiki.json")
    tokenizer = Tokens::TokenizerImpl.from_json(json_str)

    # Normalizer: NFD + StripAccents
    normalizer = Tokens::Normalizers::Sequence.new([
      Tokens::Normalizers::NFD.new,
      Tokens::Normalizers::StripAccents.new,
    ])
    normalized = Tokens::NormalizedString.new("Héllò hôw are ü?")
    normalizer.normalize(normalized)
    normalized.get.should eq("Hello how are u?")

    tokenizer.with_normalizer(normalizer)

    # Pre-tokenizer: Whitespace
    pre_tokenizer = Tokens::PreTokenizers::Whitespace.new
    pretokenized = Tokens::PreTokenizedString.new("Hello! How are you? I'm fine, thank you.")
    pre_tokenizer.pre_tokenize(pretokenized)

    splits = pretokenized.get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
    splits.should eq([
      {"Hello", {0_u32, 5_u32}, nil},
      {"!", {5_u32, 6_u32}, nil},
      {"How", {7_u32, 10_u32}, nil},
      {"are", {11_u32, 14_u32}, nil},
      {"you", {15_u32, 18_u32}, nil},
      {"?", {18_u32, 19_u32}, nil},
      {"I", {20_u32, 21_u32}, nil},
      {"'", {21_u32, 22_u32}, nil},
      {"m", {22_u32, 23_u32}, nil},
      {"fine", {24_u32, 28_u32}, nil},
      {",", {28_u32, 29_u32}, nil},
      {"thank", {30_u32, 35_u32}, nil},
      {"you", {36_u32, 39_u32}, nil},
      {".", {39_u32, 40_u32}, nil},
    ])

    # Combined pre-tokenizer: Whitespace + Digits
    pre_tokenizer = Tokens::PreTokenizers::Sequence.new([
      Tokens::PreTokenizers::Whitespace.new,
      Tokens::PreTokenizers::Digits.new(true),
    ])
    pretokenized = Tokens::PreTokenizedString.new("Call 911!")
    pre_tokenizer.pre_tokenize(pretokenized)
    splits = pretokenized.get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte)
    splits.should eq([
      {"Call", {0_u32, 4_u32}, nil},
      {"9", {5_u32, 6_u32}, nil},
      {"1", {6_u32, 7_u32}, nil},
      {"1", {7_u32, 8_u32}, nil},
      {"!", {8_u32, 9_u32}, nil},
    ])

    tokenizer.with_pre_tokenizer(pre_tokenizer)

    # Post-processor: TemplateProcessing
    tokenizer.with_post_processor(
      Tokens::PostProcessors::TemplateProcessing.build(
        Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP]"),
        Tokens::PostProcessors::ProcTemplate.parse("[CLS] $A [SEP] $B:1 [SEP]:1"),
        Tokens::PostProcessors::TokensMap.from_tuples([
          {"[CLS]", 1_u32},
          {"[SEP]", 2_u32},
        ]),
      )
    )

    # Encoding and decoding — divergence starts here
    output = tokenizer.encode("Hello, y'all! How are you \u{1F601} ?", true)
    output.ids.should eq([1_u32, 27253_u32, 16_u32, 93_u32, 11_u32, 5097_u32, 5_u32, 7961_u32, 5112_u32, 6218_u32, 0_u32, 35_u32, 2_u32])

    decoded = tokenizer.decode([1_u32, 27253_u32, 16_u32, 93_u32, 11_u32, 5097_u32, 5_u32, 7961_u32, 5112_u32, 6218_u32, 0_u32, 35_u32, 2_u32], true)
    decoded.should eq("Hello , y ' all ! How are you ?")
  end

  it "pipeline_bert" do
    json_str = File.read("data/bert-wiki.json")
    bert_tokenizer = Tokens::TokenizerImpl.from_json(json_str)

    output = bert_tokenizer.encode("Welcome to the \u{1F917} Tokenizers library.", true)

    output.tokens.should eq(["[CLS]", "welcome", "to", "the", "[UNK]", "tok", "##eni", "##zer", "##s", "library", ".", "[SEP]"])

    decoded = bert_tokenizer.decode(output.ids, true)
    decoded.should eq("welcome to the tok ##eni ##zer ##s library .")

    # Add WordPiece decoder for proper decoding
    bert_tokenizer.with_decoder(Tokens::Decoders::WordPiece.default)
    decoded = bert_tokenizer.decode(output.ids, true)
    decoded.should eq("welcome to the tokenizers library.")
  end
end
