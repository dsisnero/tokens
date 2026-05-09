require "../spec_helper"

private class LowercaseNormalizer
  include Tokens::Normalizer

  def normalize(normalized : Tokens::NormalizedString) : Nil
    normalized.lowercase
  end
end

private class ModelMock
  include Tokens::Model

  getter vocab : Hash(String, UInt32)
  @vocab_r : Hash(UInt32, String)

  def initialize(pairs : Array(Tuple(String, UInt32)))
    @vocab = pairs.to_h
    @vocab_r = @vocab.each_with_object({} of UInt32 => String) do |(token, id), acc|
      acc[id] = token
    end
  end

  def tokenize(sequence : String) : Array(Tokens::Token)
    [] of Tokens::Token
  end

  def token_to_id(token : String) : UInt32?
    @vocab[token]?
  end

  def id_to_token(id : UInt32) : String?
    @vocab_r[id]?
  end

  def vocab_size : UInt32
    @vocab.size.to_u32
  end

  def save(folder : String, name : String? = nil) : Array(String)
    [] of String
  end

  def trainer
    nil
  end
end

private def simplify_output(result : Tokens::PreTokenizedString)
  result.get_splits(Tokens::OffsetReferential::Original, Tokens::OffsetType::Byte).map do |string, _, tokens|
    {
      string,
      tokens.try(&.map(&.id)),
    }
  end
end

module Tokens
  describe AddedVocabulary do
    it "can add tokens" do
      model = ModelMock.new([{"test", 0_u32}, {"tost", 1_u32}])
      vocab = AddedVocabulary.new

      vocab.add_tokens([AddedToken.from("added_token_1", false)], model, nil).should eq(1_u64)
      vocab.len.should eq(1)

      vocab.add_tokens([
        AddedToken.from("added_token_2", false),
        AddedToken.from("added_token_2", false),
      ], model, nil).should eq(1_u64)
      vocab.len.should eq(2)

      added_token = AddedToken.from("test", false)
      vocab.add_tokens([added_token], model, nil).should eq(1_u64)
      vocab.len.should eq(3)
      vocab.get_added_tokens_decoder[0_u32].should eq(added_token)
    end

    it "can add special tokens" do
      model = ModelMock.new([{"test", 0_u32}, {"tost", 1_u32}])
      vocab = AddedVocabulary.new

      vocab.add_special_tokens([AddedToken.from("added_token_1", true)], model, nil).should eq(1_u64)
      vocab.len.should eq(1)

      vocab.add_special_tokens([
        AddedToken.from("added_token_2", true),
        AddedToken.from("added_token_2", true),
      ], model, nil).should eq(1_u64)
      vocab.len.should eq(2)

      vocab.add_special_tokens([AddedToken.from("test", true)], model, nil).should eq(1_u64)
      vocab.len.should eq(3)
      vocab.is_special_token("test").should be_true
      vocab.get_added_tokens_decoder.should eq({
        0_u32 => AddedToken.from("test", true),
        2_u32 => AddedToken.from("added_token_1", true),
        3_u32 => AddedToken.from("added_token_2", true),
      })

      vocab.add_tokens([
        AddedToken.from("tost", true),
        AddedToken.from("another_two", false),
      ], model, nil)
      vocab.len.should eq(5)
      vocab.get_vocab["another_two"].should eq(4_u32)

      vocab.add_special_tokens([AddedToken.from("another_two", true)], model, nil).should eq(1_u64)
      vocab.len.should eq(5)
      vocab.get_vocab["another_two"].should eq(4_u32)

      token = AddedToken.from("Hey", false)
      token.content = "hey"
      token.content.should eq("hey")
      token.special = true
      token.special.should be_true
    end

    it "can extract added tokens" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("my", false),
        AddedToken.from("name", false),
      ], model, nil)
      vocab.add_special_tokens([
        AddedToken.from("[CLS]", true),
        AddedToken.from("[SEP]", true),
      ], model, nil)

      result = vocab.extract_and_normalize(nil, "[CLS] My name is Anthony [SEP]")
      simplify_output(result).should eq([
        {"[CLS]", [2_u32]},
        {" My ", nil},
        {"name", [1_u32]},
        {" is Anthony ", nil},
        {"[SEP]", [3_u32]},
      ])
    end

    it "supports option use cases" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("my", false).lstrip(true).rstrip(true),
        AddedToken.from("name", false),
        AddedToken.from("ony", false).single_word(true),
      ], model, normalizer)
      vocab.add_special_tokens([
        AddedToken.from("[CLS]", true),
        AddedToken.from("[SEP]", true),
      ], model, normalizer)

      result = vocab.extract_and_normalize(normalizer, "[CLS] My name is Anthony [SEP]")
      simplify_output(result).should eq([
        {"[CLS]", [3_u32]},
        {" my ", [0_u32]},
        {"name", [1_u32]},
        {" is anthony ", nil},
        {"[SEP]", [4_u32]},
      ])
    end

    it "returns an empty match for the empty string" do
      vocab = AddedVocabulary.new
      vocab.find_matches("", [] of Tuple(String, UInt32)).should eq([{nil, {0_u32, 0_u32}}])
    end

    it "honors single_word boundaries" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("<mask>", false).single_word(true),
      ], model, normalizer)

      result = vocab.extract_and_normalize(normalizer, "<mask> My name <mask> A<mask> <mask>ony <mask>")
      simplify_output(result).should eq([
        {"<mask>", [0_u32]},
        {" my name ", nil},
        {"<mask>", [0_u32]},
        {" a<mask> <mask>ony ", nil},
        {"<mask>", [0_u32]},
      ])
    end

    it "treats unicode combining marks as word characters for single_word matching" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("<mask>", false).single_word(true),
      ], model, normalizer)

      result = vocab.extract_and_normalize(normalizer, "<mask>, <mask>- \u0330<mask>")
      simplify_output(result).should eq([
        {"<mask>", [0_u32]},
        {", ", nil},
        {"<mask>", [0_u32]},
        {"- \u0330<mask>", nil},
      ])
    end

    it "strips unicode whitespace around lstrip/rstrip tokens" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("<mask>", false).lstrip(true).rstrip(true).single_word(true),
      ], model, normalizer)

      result = vocab.extract_and_normalize(normalizer, "Hi <mask> there\t<mask>\t<mask>\u{2000}")
      simplify_output(result).should eq([
        {"hi", nil},
        {" <mask> ", [0_u32]},
        {"there", nil},
        {"\t<mask>\t", [0_u32]},
        {"<mask>\u{2000}", [0_u32]},
      ])
    end

    it "can skip encoding special tokens while still matching non-special overlaps" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("<mask>", true).lstrip(true).rstrip(true).single_word(true),
        AddedToken.from("ask>", false),
        AddedToken.from("<pad>", true),
      ], model, normalizer)
      vocab.set_encode_special_tokens(true)

      result = vocab.extract_and_normalize(normalizer, "Hi <mask> there\t<mask>\t<mask>\u{2000} <pad> <mask><pad><pad>")
      simplify_output(result).should eq([
        {"hi <m", nil},
        {"ask>", [1_u32]},
        {" there\t<m", nil},
        {"ask>", [1_u32]},
        {"\t<m", nil},
        {"ask>", [1_u32]},
        {"\u{2000} <pad> <m", nil},
        {"ask>", [1_u32]},
        {"<pad><pad>", nil},
      ])

      vocab.set_encode_special_tokens(false)
      result = vocab.extract_and_normalize(normalizer, "Hi <mask> there\t<mask>\t<mask>\u{2000} <pad> <mask><pad><pad>")
      simplify_output(result).should eq([
        {"hi", nil},
        {" <mask> ", [0_u32]},
        {"there", nil},
        {"\t<mask>\t", [0_u32]},
        {"<mask>\u{2000} ", [0_u32]},
        {"<pad>", [2_u32]},
        {" <mask>", [0_u32]},
        {"<pad>", [2_u32]},
        {"<pad>", [2_u32]},
      ])
    end

    it "preserves original content while caching normalized decode text" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("Hello", false),
        AddedToken.from("[CLS]", true),
      ], model, normalizer)

      decoder = vocab.get_added_tokens_decoder
      decoder.values.any? { |token| token.content == "Hello" }.should be_true
      decoder.values.any? { |token| token.content == "[CLS]" }.should be_true

      hello_id = vocab.get_vocab["Hello"]
      cls_id = vocab.get_vocab["[CLS]"]
      vocab.simple_id_to_token(hello_id).should eq("hello")
      vocab.simple_id_to_token(cls_id).should eq("[CLS]")
    end

    it "refreshes normalized tokens when the normalizer changes" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = LowercaseNormalizer.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([AddedToken.from("Hello", false)], model, nil)
      hello_id = vocab.get_vocab["Hello"]
      vocab.simple_id_to_token(hello_id).should eq("Hello")

      vocab.refresh_normalized_tokens(normalizer)
      vocab.simple_id_to_token(hello_id).should eq("hello")

      result = vocab.extract_and_normalize(normalizer, "Hello world")
      simplify_output(result).first.should eq({"hello", [0_u32]})
    end

    it "supports byte-level normalization" do
      model = ModelMock.new([] of Tuple(String, UInt32))
      normalizer = Tokens::Normalizers::ByteLevel.new
      vocab = AddedVocabulary.new

      vocab.add_tokens([
        AddedToken.from("my", false),
        AddedToken.from("今", false),
      ], model, normalizer)

      simplify_output(vocab.extract_and_normalize(normalizer, "my今")).should eq([
        {"my", [0_u32]},
        {"ä»Ĭ", [1_u32]},
      ])
    end
  end
end
