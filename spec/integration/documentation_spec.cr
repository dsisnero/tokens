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
end
