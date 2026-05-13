require "../src/tokens"
require "benchmark"

module TokensBenchmarks
  CORPUS          = File.read("data/small.txt") * 5
  LINES           = CORPUS.lines.reject(&.strip.empty?)
  BATCH_SIZE      = 1000
  BERT_VOCAB_PATH = "data/bert-base-uncased-vocab.txt"

  def self.create_bert_tokenizer : Tokens::TokenizerImpl
    model = Tokens::Models::WordPiece.build(
      Tokens::Models::WordPiece.read_file(BERT_VOCAB_PATH)
    )
    sep_id = model.token_to_id("[SEP]") || raise "WordPiece vocab missing [SEP]"
    cls_id = model.token_to_id("[CLS]") || raise "WordPiece vocab missing [CLS]"

    Tokens::TokenizerImpl.new(model)
      .with_pre_tokenizer(Tokens::PreTokenizers::BertPreTokenizer.new)
      .with_normalizer(Tokens::Normalizers::BertNormalizer.new)
      .with_decoder(Tokens::Decoders::WordPiece.default)
      .with_post_processor(
        Tokens::PostProcessors::BertProcessing.new(
          {"[SEP]", sep_id},
          {"[CLS]", cls_id},
        )
      )
  end

  def self.run
    puts "=" * 70
    puts "BERT Benchmark — WordPiece encode / batch / train"
    puts "Corpus: #{CORPUS.bytesize / 1024} KB, #{LINES.size} lines"
    puts "=" * 70

    tokenizer = create_bert_tokenizer

    batches = LINES.each_slice(BATCH_SIZE).to_a

    GC.collect
    sleep 0.1.seconds

    Benchmark.bm do |x|
      x.report("WordPiece BERT encode 5x") do
        5.times do
          LINES.each { |line| tokenizer.encode(line, true) }
        end
      end

      x.report("WordPiece BERT encode_batch 5x") do
        5.times do
          batches.each { |batch| tokenizer.encode_batch(batch, true) }
        end
      end

      x.report("WordPiece train small 3x") do
        3.times do
          model = Tokens::Models::WordPiece.default
          t = Tokens::TokenizerImpl.new(model)
          t.with_pre_tokenizer(Tokens::PreTokenizers::Whitespace.new)
          trainer = Tokens::Models::WordPieceTrainer.new(
            show_progress: false,
            vocab_size: 30000,
          )
          t.train_from_files(trainer, ["data/small.txt"])
        end
      end
    end
  end
end

TokensBenchmarks.run
