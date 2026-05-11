require "../spec_helper"

# Helper: create a byte-level BPE tokenizer matching upstream get_byte_level
private def get_byte_level(add_prefix_space : Bool, trim_offsets : Bool) : Tokens::TokenizerImpl
  bpe = Tokens::Models::BPE::BPE.from_file("data/gpt2-vocab.json", "data/gpt2-merges.txt").build
  tokenizer = Tokens::TokenizerImpl.new(bpe)
  tokenizer.with_pre_tokenizer(Tokens::PreTokenizerWrapper.from(
    Tokens::PreTokenizers::ByteLevel.default.add_prefix_space(add_prefix_space)
  ))
  tokenizer.with_decoder(Tokens::DecoderWrapper.from(
    Tokens::PreTokenizers::ByteLevel.default
  ))
  tokenizer.with_post_processor(Tokens::PostProcessorWrapper.from(
    Tokens::PreTokenizers::ByteLevel.default.trim_offsets(trim_offsets)
  ))
  tokenizer
end

# Helper: verify offset ranges point to correct substring
private def check_offsets(input : String, output : Tokens::Encoding, idx : Int32, expected : String)
  off = output.offsets[idx]
  input.byte_slice(off[0].to_i32, (off[1] - off[0]).to_i32).should eq(expected)
end

describe "Offsets integration tests" do
  it "byte_level_basic" do
    tokenizer = get_byte_level(true, false)
    input = "Hello there, how are you?"
    output = tokenizer.encode(input, false)
    check_offsets(input, output, 0, "Hello")
    check_offsets(input, output, 1, " there")
    check_offsets(input, output, 2, ",")
    check_offsets(input, output, 3, " how")
    check_offsets(input, output, 4, " are")
    check_offsets(input, output, 5, " you")
    check_offsets(input, output, 6, "?")

    tokenizer = get_byte_level(true, true)
    output = tokenizer.encode(input, false)
    check_offsets(input, output, 0, "Hello")
    check_offsets(input, output, 1, "there")
    check_offsets(input, output, 2, ",")
    check_offsets(input, output, 3, "how")
    check_offsets(input, output, 4, "are")
    check_offsets(input, output, 5, "you")
    check_offsets(input, output, 6, "?")
  end

  it "byte_level_unicode" do
    tokenizer = get_byte_level(true, false)
    input = "i⭢j"
    output = tokenizer.encode(input, false)
    check_offsets(input, output, 1, "⭢")
    check_offsets(input, output, 2, "⭢")
    check_offsets(input, output, 3, "⭢")
  end

  it "byte_level_double_sequence" do
    input_a = "My name is Anthony"
    input_b = "What is my name?"

    tokenizer = get_byte_level(true, false)
    output = tokenizer.encode({input_a, input_b}, false)

    output.offsets.should eq([
      {0_u32, 2_u32}, {2_u32, 7_u32}, {7_u32, 10_u32}, {10_u32, 18_u32},
      {0_u32, 4_u32}, {4_u32, 7_u32}, {7_u32, 10_u32}, {10_u32, 15_u32}, {15_u32, 16_u32},
    ])
    output.words.should eq([0_u32, 1_u32, 2_u32, 3_u32, 0_u32, 1_u32, 2_u32, 3_u32, 4_u32])
    output.type_ids.should eq([0_u32, 0_u32, 0_u32, 0_u32, 1_u32, 1_u32, 1_u32, 1_u32, 1_u32])

    tokenizer = get_byte_level(true, true)
    output = tokenizer.encode({input_a, input_b}, false)
    output.offsets.should eq([
      {0_u32, 2_u32}, {3_u32, 7_u32}, {8_u32, 10_u32}, {11_u32, 18_u32},
      {0_u32, 4_u32}, {5_u32, 7_u32}, {8_u32, 10_u32}, {11_u32, 15_u32}, {15_u32, 16_u32},
    ])
  end
end
