require "../src/tokens"
require "benchmark"

module TokensBenchmarks
  CORPUS       = File.read("data/small.txt") * 5 # ~35KB
  LINES        = CORPUS.lines.reject(&.strip.empty?).first(50)
  ALL_LINES    = CORPUS.lines.reject(&.strip.empty?)
  LARGE_LINES  = (CORPUS * 30).lines.reject(&.strip.empty?).first(500)
  ROBERTA_JSON = File.read("data/roberta.json")
  BERT_JSON    = File.read("data/bert-wiki.json")

  def self.load_bpe : Tokens::TokenizerImpl
    Tokens::TokenizerImpl.from_json(ROBERTA_JSON)
  end

  def self.load_bert : Tokens::TokenizerImpl
    Tokens::TokenizerImpl.from_json(BERT_JSON)
  end

  def self.load_bpe_with_template_post_processor : Tokens::TokenizerImpl
    tokenizer = load_bpe
    bos_id = tokenizer.token_to_id("<s>") || raise "RoBERTa tokenizer missing <s>"
    eos_id = tokenizer.token_to_id("</s>") || raise "RoBERTa tokenizer missing </s>"

    tokenizer.with_post_processor(
      Tokens::PostProcessors::TemplateProcessing.build(
        Tokens::PostProcessors::ProcTemplate.parse("<s> $A </s>"),
        Tokens::PostProcessors::ProcTemplate.parse("<s> $A </s> $B:1 </s>:1"),
        Tokens::PostProcessors::TokensMap.from_tuples([
          {"<s>", bos_id}, {"</s>", eos_id},
        ]),
      )
    )
  end

  def self.run
    puts "=" * 70
    puts "Baseline Performance (release mode)"
    puts "Corpus: #{CORPUS.bytesize / 1024} KB"
    puts "=" * 70

    GC.collect
    sleep 0.1.seconds

    bpe = load_bpe
    bert = load_bert
    decode_ids = bpe.encode(CORPUS, false).ids
    decode_batch_ids = LINES.map { |line| bpe.encode(line, false).ids }
    large_decode_ids = LARGE_LINES.map { |line| bpe.encode(line, false).ids }
    bpe_with_post = load_bpe_with_template_post_processor

    Benchmark.bm do |x|
      x.report("encode BPE 100x") do
        100.times { bpe.encode(CORPUS, false).ids.size }
      end

      x.report("encode WordPiece 100x") do
        100.times { bert.encode(CORPUS, true).ids.size }
      end

      x.report("encode_batch 20x50ln") do
        20.times { bpe.encode_batch(LINES, false).size }
      end

      x.report("encode_batch_fast 20x50ln") do
        20.times { bpe.encode_batch_fast(LINES, false).size }
      end

      x.report("encode_batch_char_offsets 20x50ln") do
        20.times { bpe.encode_batch_char_offsets(LINES, false).size }
      end

      x.report("decode_batch 20x50ln") do
        20.times { bpe.decode_batch(decode_batch_ids, false).size }
      end

      x.report("encode_batch 5x500ln") do
        5.times { bpe.encode_batch(LARGE_LINES, false).size }
      end

      x.report("encode_batch_fast 5x500ln") do
        5.times { bpe.encode_batch_fast(LARGE_LINES, false).size }
      end

      x.report("decode_batch 5x500ln") do
        5.times { bpe.decode_batch(large_decode_ids, false).size }
      end

      x.report("decode 100x") do
        100.times { bpe.decode(decode_ids, false).bytesize }
      end

      x.report("deserialize 50x") do
        50.times do
          t = Tokens::TokenizerImpl.from_json(ROBERTA_JSON)
          t.get_vocab_size(false)
        end
      end

      x.report("train BPE 5x") do
        5.times do
          model = Tokens::Models::BPE::BpeBuilder.new.unk_token("[UNK]").build
          t = Tokens::TokenizerImpl.new(model)
          trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
            .show_progress(false).vocab_size(500).min_frequency(0_u64).build
          t.train_from_files(trainer, ["data/small.txt"])
        end
      end

      x.report("post_process 100x") do
        100.times { bpe_with_post.encode(CORPUS, true).ids.size }
      end
    end
  end
end

TokensBenchmarks.run
