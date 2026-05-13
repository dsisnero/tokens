require "../src/tokens"
require "benchmark"

module TokensBenchmarks
  CORPUS     = File.read("data/small.txt") * 30
  LINES      = CORPUS.lines.reject(&.strip.empty?)
  BATCH_SIZE = 1000
  LLAMA_JSON = File.read("data/llama-3-tokenizer.json")

  def self.run
    puts "=" * 70
    puts "Llama3 Benchmark — encode / batch / concurrent long-context"
    puts "Corpus: #{CORPUS.bytesize / 1024} KB, #{LINES.size} lines"
    puts "=" * 70

    tokenizer = Tokens::TokenizerImpl.from_json(LLAMA_JSON)

    batches = LINES.each_slice(BATCH_SIZE).to_a

    lines_per_thread = 1000
    all_lines = LINES

    GC.collect
    sleep 0.1.seconds

    Benchmark.bm do |x|
      x.report("llama3-encode 5x") do
        5.times do
          LINES.each { |line| tokenizer.encode(line, false) }
        end
      end

      x.report("llama3-encode_batch 5x") do
        5.times do
          batches.each { |batch| tokenizer.encode_batch(batch, false) }
        end
      end

      x.report("llama3-encode_batch_char_offsets 5x") do
        5.times do
          batches.each { |batch| tokenizer.encode_batch_char_offsets(batch, false) }
        end
      end

      {1, 2, 4, 8}.each do |num_threads|
        thread_lines = all_lines.size // num_threads
        inputs = (0...num_threads).map do |i|
          start = i * thread_lines
          finish = (start + thread_lines).clamp(..all_lines.size)
          all_lines[start...finish].join("\n")
        end

        x.report("llama3-concurrent-#{num_threads}t") do
          channel = Channel(Nil).new(num_threads)
          inputs.each do |input|
            spawn do
              tokenizer.encode(input, false)
              channel.send(nil)
            end
          end
          num_threads.times { channel.receive }
        end
      end

      x.report("BPE train big 3x") do
        3.times do
          model = Tokens::Models::BPE::BpeBuilder.new.unk_token("[UNK]").build
          t = Tokens::TokenizerImpl.new(model)
          trainer = Tokens::Models::BPE::BpeTrainerBuilder.new
            .show_progress(false)
            .vocab_size(500)
            .min_frequency(0_u64)
            .build
          t.train_from_files(trainer, ["data/small.txt"])
        end
      end
    end
  end
end

TokensBenchmarks.run
