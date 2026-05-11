require "../spec_helper"

describe Tokens::Models::Unigram::UnigramTrainer do
  it "to_log_prob normalizes scores" do
    pieces = [{"", 1.0_f64}, {"", 2.0_f64}] of Tuple(String, Float64)
    Tokens::Models::Unigram::Unigram.to_log_prob(pieces)
    (pieces[0][1] + 1.098).abs.should be < 0.01
    (pieces[1][1] + 0.405).abs.should be < 0.01
  end

  it "digamma computes correctly" do
    (Tokens::Models::Unigram::Unigram.digamma(1.0) + 0.5772).abs.should be < 0.001
    (Tokens::Models::Unigram::Unigram.digamma(2.0) - 0.4228).abs.should be < 0.001
    (Tokens::Models::Unigram::Unigram.digamma(10.0) - 2.25175).abs.should be < 0.001
    (Tokens::Models::Unigram::Unigram.digamma(0.001) + 1000.58).abs.should be < 0.02
  end

  it "default trainer settings" do
    trainer = Tokens::Models::Unigram::UnigramTrainer.new
    trainer.show_progress.should be_true
    trainer.vocab_size.should eq(8000_u32)
    trainer.n_sub_iterations.should eq(2_u32)
    (trainer.shrinking_factor - 0.75).abs.should be < 0.001
    trainer.max_piece_length.should eq(16)
  end

  it "trainer includes Trainer module" do
    trainer = Tokens::Models::Unigram::UnigramTrainer.new
    trainer.should_show_progress?.should be_true
  end

  it "required_chars from sentences" do
    trainer = Tokens::Models::Unigram::UnigramTrainer.new(show_progress: false)

    sentences = [
      {"This is a", 1_u32},
      {"こんにちは友達", 1_u32},
    ]

    required = trainer.required_chars(sentences)
    required.size.should eq(13)
  end

  it "train returns special tokens" do
    trainer = Tokens::Models::Unigram::UnigramTrainer.new(
      show_progress: false,
      vocab_size: 100_u32,
      special_tokens: [
        Tokens::AddedToken.from("[SEP]", true),
        Tokens::AddedToken.from("[CLS]", true),
      ],
    )

    model = Tokens::Models::Unigram::Unigram.default
    result = trainer.train(model)
    result.should be_a(Array(Tokens::AddedToken))
    result.size.should eq(2)
  end
end
