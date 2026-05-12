require "../spec_helper"
require "../../src/tokens/models/bpe/model"
require "../../src/tokens/models/bpe/trainer"

describe "Training integration tests" do
  it "bpe_values_after_training" do
    model = Tokens::Models::BPE::BpeBuilder.new
      .unk_token("[UNK]")
      .dropout(0.1_f32)
      .build
    tokenizer = Tokens::TokenizerImpl.new(model)

    trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
      .show_progress(false)
      .build

    tokenizer.train_from_files(trainer, ["data/small.txt"])

    model.dropout.should eq(0.1_f32)
    model.unk_token.should eq("[UNK]")
  end

  it "bpe_continuing_subword_prefix_error" do
    model = Tokens::Models::BPE::BpeBuilder.new
      .unk_token("[UNK]")
      .continuing_subword_prefix("##")
      .build
    tokenizer = Tokens::TokenizerImpl.new(model)

    tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)

    trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
      .show_progress(false)
      .build

    tokenizer.train_from_files(trainer, ["data/small.txt"])

    json_str = tokenizer.to_json
    File.write("tokenizer.json", json_str)
    loaded = Tokens::TokenizerImpl.from_json(File.read("tokenizer.json"))
    File.delete("tokenizer.json")

    loaded.get_vocab_size(false).should eq(1526)
  end
end
