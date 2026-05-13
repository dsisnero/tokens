require "../src/tokens"
require "benchmark"

module TokensBenchmarks
  CORPUS      = File.read("data/small.txt") * 5
  LINES       = CORPUS.lines.reject(&.strip.empty?)
  ALBERT_JSON = File.read("data/albert-base-v1-tokenizer.json")

  def self.create_processor : Tokens::PostProcessors::TemplateProcessing
    Tokens::PostProcessors::TemplateProcessing.build(
      Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0"),
      Tokens::PostProcessors::ProcTemplate.parse("[CLS]:0 $A:0 [SEP]:0 $B:1 [SEP]:1"),
      Tokens::PostProcessors::TokensMap.from_tuples([
        {"[CLS]", 0_u32}, {"[SEP]", 1_u32},
      ]),
    )
  end

  def self.run
    puts "=" * 70
    puts "Layout Benchmark — TemplateProcessing"
    puts "Corpus: #{CORPUS.bytesize / 1024} KB, #{LINES.size} lines"
    puts "=" * 70

    tokenizer = Tokens::TokenizerImpl.from_json(ALBERT_JSON)
    processor = create_processor

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
