require "../src/tokens"
require "benchmark"

module TokensBenchmarks
  CORPUS      = File.read("data/small.txt") * 5
  LINES       = CORPUS.lines.reject(&.strip.empty?)
  ALBERT_JSON = File.read("data/albert-base-v1-tokenizer.json")

  def self.create_processor(tokenizer : Tokens::TokenizerImpl) : Tokens::PostProcessors::TemplateProcessing
    cls_id = tokenizer.token_to_id("[CLS]") || raise "ALBERT tokenizer missing [CLS]"
    sep_id = tokenizer.token_to_id("[SEP]") || raise "ALBERT tokenizer missing [SEP]"

    Tokens::PostProcessors::TemplateProcessing.build(
      Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0"),
      Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0 $B:1 [SEP]:1"),
      Tokens::PostProcessors::TokensMap.from_tuples([
        {"[CLS]", cls_id}, {"[SEP]", sep_id},
      ]),
    )
  end

  def self.run
    puts "=" * 70
    puts "Layout Benchmark — TemplateProcessing"
    puts "Corpus: #{CORPUS.bytesize / 1024} KB, #{LINES.size} lines"
    puts "=" * 70

    tokenizer = Tokens::TokenizerImpl.from_json(ALBERT_JSON)
    processor = create_processor(tokenizer)

    encodings = LINES.map { |line| tokenizer.encode(line, false) }

    GC.collect
    sleep 0.1.seconds

    Benchmark.bm do |x|
      x.report("TemplateProcessing single 1000x") do
        1000.times do |i|
          encoding = encodings[i % encodings.size]
          processor.process(encoding, nil, false)
        end
      end

      x.report("TemplateProcessing pair 1000x") do
        1000.times do |i|
          encoding = encodings[i % encodings.size]
          pair = encodings[(i + 1) % encodings.size]
          processor.process(encoding, pair, false)
        end
      end
    end
  end
end

TokensBenchmarks.run
