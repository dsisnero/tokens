require "../spec_helper"

private class TokenizerModelMock
  include Tokens::Model

  getter vocab : Hash(String, UInt32)
  @vocab_r : Hash(UInt32, String)

  def initialize
    @vocab = ('a'..'j').each_with_index.to_h { |char, index| {char.to_s, index.to_u32} }
    @vocab["<unk>"] = 10_u32
    @vocab_r = @vocab.each_with_object({} of UInt32 => String) do |(token, id), acc|
      acc[id] = token
    end
  end

  def tokenize(sequence : String) : Array(Tokens::Token)
    id = token_to_id(sequence) || 10_u32
    [Tokens::Token.new(id, sequence, {0_u32, sequence.bytesize.to_u32})]
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

private class WhitespaceSplitPreTokenizer
  include Tokens::PreTokenizer

  def pre_tokenize(pretokenized : Tokens::PreTokenizedString) : Nil
    pretokenized.split(->(_idx : Int32, normalized : Tokens::NormalizedString) {
      normalized.split(" ", Tokens::SplitDelimiterBehavior::Removed).map { |part| Tokens::Split.new(part) }
    })
  end
end

private def test_tokenizer
  tokenizer = Tokens::Tokenizer.new(TokenizerModelMock.new)
  tokenizer.with_pre_tokenizer(WhitespaceSplitPreTokenizer.new)
end

module Tokens
  describe Tokenizer do
    it "matches full encode when right truncation early exits" do
      input = "a b c d e f g h i j"

      tokenizer = test_tokenizer
      tokenizer.with_truncation(TruncationParams.new(
        max_length: 3_u64,
        strategy: TruncationStrategy::LongestFirst,
        stride: 0_u64,
        direction: TruncationDirection::Right
      ))

      truncated = tokenizer.encode(input, false)
      full = test_tokenizer.encode(input, false)

      truncated.ids.size.should eq(3)
      truncated.ids.should eq(full.ids.first(3))
    end

    it "keeps tail tokens for left truncation" do
      input = "a b c d e f g h i j"

      tokenizer = test_tokenizer
      tokenizer.with_truncation(TruncationParams.new(
        max_length: 3_u64,
        strategy: TruncationStrategy::LongestFirst,
        stride: 0_u64,
        direction: TruncationDirection::Left
      ))

      truncated = tokenizer.encode(input, false)
      full = test_tokenizer.encode(input, false)

      truncated.ids.size.should eq(3)
      truncated.ids.should eq(full.ids.last(3))
    end

    it "truncates pairs longest_first from the right" do
      tokenizer = test_tokenizer
      tokenizer.with_truncation(TruncationParams.new(
        max_length: 6_u64,
        strategy: TruncationStrategy::LongestFirst,
        stride: 0_u64,
        direction: TruncationDirection::Right
      ))

      truncated = tokenizer.encode({"a b c d e f g h i j", "a b c d e"}, false)

      truncated.ids.should eq([0_u32, 1_u32, 2_u32, 0_u32, 1_u32, 2_u32])
    end

    it "does not truncate the first sequence for only_second" do
      tokenizer = test_tokenizer
      tokenizer.with_truncation(TruncationParams.new(
        max_length: 8_u64,
        strategy: TruncationStrategy::OnlySecond,
        stride: 0_u64,
        direction: TruncationDirection::Right
      ))

      truncated = tokenizer.encode({"a b c d e", "a b c d e f g h i j"}, false)
      full_a = test_tokenizer.encode("a b c d e", false)

      truncated.ids.size.should eq(8)
      truncated.ids.first(5).should eq(full_a.ids)
    end

    it "does not truncate the second sequence for only_first" do
      tokenizer = test_tokenizer
      tokenizer.with_truncation(TruncationParams.new(
        max_length: 8_u64,
        strategy: TruncationStrategy::OnlyFirst,
        stride: 0_u64,
        direction: TruncationDirection::Right
      ))

      truncated = tokenizer.encode({"a b c d e f g h i j", "a b c d e"}, false)
      full_b = test_tokenizer.encode("a b c d e", false)

      truncated.ids.size.should eq(8)
      truncated.ids.last(5).should eq(full_b.ids)
    end
  end
end
