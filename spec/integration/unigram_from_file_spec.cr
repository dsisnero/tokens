require "../spec_helper"

describe "Unigram from_file integration test" do
  it "test_unigram_from_file" do
    json = File.read("data/unigram.json")
    model = Tokens::Models::Unigram::Unigram.from_json(json)

    string = "吾輩《わがはい》は猫である。名前はまだ無い。"
    tokens = model.tokenize(string)
    values = tokens.map(&.value)

    values.should eq([
      "吾輩",
      "《",
      "わが",
      "はい",
      "》",
      "は",
      "猫",
      "である",
      "。",
      "名前",
      "はまだ",
      "無い",
      "。",
    ])
  end
end
