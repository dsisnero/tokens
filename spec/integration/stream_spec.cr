require "../spec_helper"

describe "Stream decode integration tests" do
  it "decode_stream_step_no_panic" do
    tokenizer_json = File.read("data/llama-3-tokenizer.json")
    tokenizer = Tokens::TokenizerImpl.from_json(tokenizer_json)

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

    # Korean: "삥뽕빵" (multi-byte tokens: [80690,98], [167,121,243], [102457,113])
    stream = tokenizer.decode_stream(false)
    stream.step(80690_u32).should be_nil
    stream.step(98_u32).should eq("삥")
    stream.step(167_u32).should be_nil
    stream.step(121_u32).should be_nil
    stream.step(243_u32).should eq("뽕")
    stream.step(102457_u32).should be_nil
    stream.step(113_u32).should eq("빵")
  end
end
