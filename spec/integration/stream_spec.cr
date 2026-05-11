require "../spec_helper"

describe "Stream decode integration tests" do
  it "decode_stream_step_no_panic" do
    tokenizer_json = File.read("data/llama-3-tokenizer.json")
    tokenizer = Tokens::TokenizerImpl.from_json(tokenizer_json)

    # "A B C D E F G H I J" using known Llama-3 token IDs
    # Upstream: tokenizer.decode_stream(false) returns DecodeStream
    # Crystal: tokenizer.decode_stream(false) returns DecodeStream
    stream = tokenizer.decode_stream(false)
    stream.step(32_u32).should eq("A")
    stream.step(426_u32).should eq(" B")
    stream.step(356_u32).should eq(" C")
    stream.step(423_u32).should eq(" D")
    stream.step(469_u32).should eq(" E")
    stream.step(435_u32).should eq(" F")
    stream.step(480_u32).should eq(" G")
    stream.step(473_u32).should eq(" H")
    stream.step(358_u32).should eq(" I")
    stream.step(622_u32).should eq(" J")
  end
end
