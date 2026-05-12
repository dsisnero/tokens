require "../spec_helper"

describe "Wiki training integration tests (upstream #[ignore])" do
  it "quicktour_slow_train" do
    model = Tokens::Models::BPE::BpeBuilder.new
      .unk_token("[UNK]")
      .build
    tokenizer = Tokens::TokenizerImpl.new(model)
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)

    trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
      .special_tokens([
        Tokens::AddedToken.new("[UNK]".to_s, true),
        Tokens::AddedToken.new("[CLS]".to_s, true),
        Tokens::AddedToken.new("[SEP]".to_s, true),
        Tokens::AddedToken.new("[PAD]".to_s, true),
        Tokens::AddedToken.new("[MASK]".to_s, true),
      ])
      .build

    tokenizer.train_from_files(trainer, ["data/small.txt"])
    tokenizer.get_vocab_size(true).should be > 0
  end

  it "train_pipeline_bert" do
    model = Tokens::Models::WordPiece.build(
      vocab: Tokens::Models::WordPiece.read_file("data/bert-base-uncased-vocab.txt"),
      unk_token: "[UNK]",
    )
    tokenizer = Tokens::TokenizerImpl.new(model)

    tokenizer.with_normalizer(
      Tokens::Normalizers::Sequence.new([
        Tokens::Normalizers::NFD.new,
        Tokens::Normalizers::Lowercase.new,
        Tokens::Normalizers::StripAccents.new,
      ])
    )
    tokenizer.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)
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

    trainer = Tokens::Models::WordPieceTrainer.new(
      show_progress: false,
      special_tokens: [
        Tokens::AddedToken.new("[UNK]".to_s, true),
        Tokens::AddedToken.new("[CLS]".to_s, true),
        Tokens::AddedToken.new("[SEP]".to_s, true),
        Tokens::AddedToken.new("[PAD]".to_s, true),
        Tokens::AddedToken.new("[MASK]".to_s, true),
      ],
    )

    tokenizer.train_from_files(trainer, ["data/small.txt"])
    tokenizer.get_vocab_size(true).should be > 0
  end
end
