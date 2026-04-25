require "../spec_helper"

module Tokens
  module Models
    module BPE
      describe BPE do
        describe "Word" do
          it "adds symbols and merges pairs" do
            word = Word.new
            word.add(0_u32, 1_u32)
            word.add(1_u32, 1_u32)
            word.add(2_u32, 1_u32)
            word.add(2_u32, 1_u32)
            word.add(3_u32, 1_u32)

            changes = word.merge(2_u32, 2_u32, 4_u32, UInt32::MAX)
            word.get_chars.should eq([0_u32, 1_u32, 4_u32, 3_u32])

            changes.should eq([
              { {1_u32, 2_u32}, -1_i32 },
              { {1_u32, 4_u32}, 1_i32 },
              { {2_u32, 3_u32}, -1_i32 },
              { {4_u32, 3_u32}, 1_i32 },
            ])
          end

          it "merges with max length cap" do
            word = Word.new
            word.add(0_u32, 1_u32)
            word.add(1_u32, 1_u32)
            word.add(2_u32, 1_u32)
            word.add(2_u32, 1_u32)
            word.add(3_u32, 1_u32)

            changes = word.merge(2_u32, 2_u32, 4_u32, 2_u32)
            word.get_chars.should eq([0_u32, 1_u32, 4_u32, 3_u32])

            # The pairs (1,4) and (4,3) would both result in tokens
            # longer than 2 bytes, so they are excluded from changes.
            changes.should eq([
              { {1_u32, 2_u32}, -1_i32 },
              { {2_u32, 3_u32}, -1_i32 },
            ])
          end
        end

        describe "Tokenize" do
          it "tokenizes with simple BPE model" do
            vocab = {
              "u"         => 0_u32,
              "n"         => 1_u32,
              "r"         => 2_u32,
              "e"         => 3_u32,
              "l"         => 4_u32,
              "a"         => 5_u32,
              "t"         => 6_u32,
              "d"         => 7_u32,
              "re"        => 8_u32,
              "at"        => 9_u32,
              "ed"        => 10_u32,
              "un"        => 11_u32,
              "ated"      => 12_u32,
              "rel"       => 13_u32,
              "related"   => 14_u32,
              "unrelated" => 15_u32,
            }
            merges = [
              {"r", "e"},
              {"a", "t"},
              {"e", "d"},
              {"u", "n"},
              {"at", "ed"},
              {"re", "l"},
              {"rel", "ated"},
              {"un", "related"},
            ]
            bpe = BPE.new(vocab, merges)

            tokens = bpe.tokenize("unrelated")
            tokens.should eq([
              Token.new(15_u32, "unrelated", {0_u32, 9_u32}),
            ])
          end

          it "returns empty array for empty input" do
            bpe = BPE.new({"a" => 0_u32}, [] of {String, String})
            bpe.tokenize("").should eq([] of Token)
          end

          it "uses UNK token for unknown characters (not fused)" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
            end

            tokens = bpe.tokenize("c")
            tokens.should eq([Token.new(0_u32, "<unk>", {0_u32, 1_u32})])

            tokens = bpe.tokenize("cc")
            tokens.should eq([
              Token.new(0_u32, "<unk>", {0_u32, 1_u32}),
              Token.new(0_u32, "<unk>", {1_u32, 2_u32}),
            ])

            tokens = bpe.tokenize("accb")
            tokens.should eq([
              Token.new(1_u32, "a", {0_u32, 1_u32}),
              Token.new(0_u32, "<unk>", {1_u32, 2_u32}),
              Token.new(0_u32, "<unk>", {2_u32, 3_u32}),
              Token.new(2_u32, "b", {3_u32, 4_u32}),
            ])
          end

          it "fuses UNK tokens when fuse_unk is true" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
              b.fuse_unk(true)
            end

            tokens = bpe.tokenize("c")
            tokens.should eq([Token.new(0_u32, "<unk>", {0_u32, 1_u32})])

            tokens = bpe.tokenize("cc")
            tokens.should eq([Token.new(0_u32, "<unk>", {0_u32, 2_u32})])

            tokens = bpe.tokenize("accb")
            tokens.should eq([
              Token.new(1_u32, "a", {0_u32, 1_u32}),
              Token.new(0_u32, "<unk>", {1_u32, 3_u32}),
              Token.new(2_u32, "b", {3_u32, 4_u32}),
            ])
          end

          it "supports continuing_subword_prefix" do
            vocab = {
              "a"   => 0_u32,
              "##b" => 1_u32,
              "##c" => 2_u32,
              "ab"  => 3_u32,
              "abc" => 4_u32,
            }
            merges = [
              {"a", "##b"},
              {"ab", "##c"},
            ]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.unk_token("[UNK]")
              b.continuing_subword_prefix("##")
            end

            tokens = bpe.tokenize("ab")
            tokens.should eq([Token.new(3_u32, "ab", {0_u32, 2_u32})])

            tokens = bpe.tokenize("abc")
            tokens.should eq([Token.new(4_u32, "abc", {0_u32, 3_u32})])

            bpe.continuing_subword_prefix.should eq("##")
          end

          it "supports byte_fallback" do
            vocab = {"<unk>" => 0_u32, "<0x61>" => 1_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
              b.byte_fallback(true)
            end

            tokens = bpe.tokenize("c")
            tokens.should eq([Token.new(0_u32, "<unk>", {0_u32, 1_u32})])

            tokens = bpe.tokenize("a")
            tokens.should eq([Token.new(1_u32, "<0x61>", {0_u32, 1_u32})])
          end

          it "supports byte_fallback for newline" do
            vocab = {"<unk>" => 0_u32, "<0x0A>" => 1_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
              b.byte_fallback(true)
            end

            tokens = bpe.tokenize("\n")
            tokens.should eq([Token.new(1_u32, "<0x0A>", {0_u32, 1_u32})])
          end

          it "supports ignore_merges" do
            vocab = {
              ".:.:"        => 0_u32,
              "Ġbelirtilen" => 1_u32,
              "."           => 2_u32,
              ":"           => 3_u32,
              "bel"         => 4_u32,
              "irtilen"     => 5_u32,
              "Ġ"           => 6_u32,
              ".:"          => 7_u32,
              "belirtilen"  => 8_u32,
              ".:."         => 9_u32,
              "be"          => 10_u32,
              "l"           => 11_u32,
              "ir"          => 12_u32,
              "ti"          => 13_u32,
              "en"          => 14_u32,
              "irtil"       => 15_u32,
              "irti"        => 16_u32,
              "i"           => 17_u32,
              "r"           => 18_u32,
              "t"           => 19_u32,
              "b"           => 20_u32,
              "e"           => 21_u32,
              "n"           => 22_u32,
            }
            merges = [
              {".", ":"},
              {"b", "e"},
              {"be", "l"},
              {"i", "r"},
              {"t", "i"},
              {"ir", "ti"},
              {"e", "n"},
              {"irti", "l"},
            ]

            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.ignore_merges(true)
            end

            tokens = bpe.tokenize(".:.:")
            tokens.should eq([Token.new(0_u32, ".:.:", {0_u32, 4_u32})])

            tokens = bpe.tokenize("Ġbelirtilen")
            tokens.should eq([Token.new(1_u32, "Ġbelirtilen", {0_u32, 12_u32})])

            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.ignore_merges(false)
            end

            tokens = bpe.tokenize(".:.:")
            tokens.should eq([
              Token.new(7_u32, ".:", {0_u32, 2_u32}),
              Token.new(7_u32, ".:", {2_u32, 4_u32}),
            ])

            tokens = bpe.tokenize("Ġbelirtilen")
            tokens.should eq([
              Token.new(6_u32, "Ġ", {0_u32, 2_u32}),
              Token.new(4_u32, "bel", {2_u32, 5_u32}),
              Token.new(15_u32, "irtil", {5_u32, 10_u32}),
              Token.new(14_u32, "en", {10_u32, 12_u32}),
            ])
          end
        end

        describe "BpeBuilder" do
          it "validates dropout range" do
            expect_raises(Exception) do
              BPE.build do |b|
                b.dropout(1.5_f32)
              end
            end
          end

          it "accepts dropout of 0.0" do
            bpe = BPE.build do |b|
              b.dropout(0.0_f32)
            end
            bpe.dropout.should eq(0.0_f32)
          end
        end

        describe "Dropout" do
          it "tokenizes with dropout=1.0 producing no merges" do
            vocab = {
              "u" => 0_u32, "n" => 1_u32, "r" => 2_u32, "e" => 3_u32,
              "l" => 4_u32, "a" => 5_u32, "t" => 6_u32, "d" => 7_u32,
              "re" => 8_u32, "at" => 9_u32, "ed" => 10_u32, "un" => 11_u32,
              "ated" => 12_u32, "rel" => 13_u32, "related" => 14_u32,
              "unrelated" => 15_u32,
            }
            merges = [
              {"r", "e"}, {"a", "t"}, {"e", "d"}, {"u", "n"},
              {"at", "ed"}, {"re", "l"}, {"rel", "ated"}, {"un", "related"},
            ]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.dropout(1.0_f32)
            end

            tokens = bpe.tokenize("unrelated")
            tokens.should eq([
              Token.new(0_u32, "u", {0_u32, 1_u32}),
              Token.new(1_u32, "n", {1_u32, 2_u32}),
              Token.new(2_u32, "r", {2_u32, 3_u32}),
              Token.new(3_u32, "e", {3_u32, 4_u32}),
              Token.new(4_u32, "l", {4_u32, 5_u32}),
              Token.new(5_u32, "a", {5_u32, 6_u32}),
              Token.new(6_u32, "t", {6_u32, 7_u32}),
              Token.new(3_u32, "e", {7_u32, 8_u32}),
              Token.new(7_u32, "d", {8_u32, 9_u32}),
            ])
          end

          it "tokenizes with dropout=0.5 producing between 1 and 9 tokens" do
            vocab = {
              "u" => 0_u32, "n" => 1_u32, "r" => 2_u32, "e" => 3_u32,
              "l" => 4_u32, "a" => 5_u32, "t" => 6_u32, "d" => 7_u32,
              "re" => 8_u32, "at" => 9_u32, "ed" => 10_u32, "un" => 11_u32,
              "ated" => 12_u32, "rel" => 13_u32, "related" => 14_u32,
              "unrelated" => 15_u32,
            }
            merges = [
              {"r", "e"}, {"a", "t"}, {"e", "d"}, {"u", "n"},
              {"at", "ed"}, {"re", "l"}, {"rel", "ated"}, {"un", "related"},
            ]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.dropout(0.5_f32)
            end

            tokens = bpe.tokenize("unrelated")
            tokens.should_not be_empty
            tokens.size.should be <= 9
          end
        end

        describe "BPE defaults" do
          it "token_to_id" do
            bpe = BPE.new({"hello" => 0_u32, "world" => 1_u32}, [] of {String, String})
            bpe.token_to_id("hello").should eq(0_u32)
            bpe.token_to_id("world").should eq(1_u32)
            bpe.token_to_id("unknown").should be_nil
          end

          it "id_to_token" do
            bpe = BPE.new({"hello" => 0_u32, "world" => 1_u32}, [] of {String, String})
            bpe.id_to_token(0_u32).should eq("hello")
            bpe.id_to_token(1_u32).should eq("world")
            bpe.id_to_token(99_u32).should be_nil
          end

          it "vocab_size" do
            bpe = BPE.new({"a" => 0_u32, "b" => 1_u32, "c" => 2_u32}, [] of {String, String})
            bpe.vocab_size.should eq(3_u32)
          end

          it "vocab" do
            vocab = {"a" => 0_u32, "b" => 1_u32}
            bpe = BPE.new(vocab, [] of {String, String})
            bpe.vocab.should eq(vocab)
          end
        end

        describe "Cache" do
          it "is per-BPE-instance" do
            vocab_a = {
              "h" => 0_u32, "e" => 1_u32, "l" => 2_u32, "o" => 3_u32,
              "he" => 4_u32, "hel" => 5_u32, "hell" => 6_u32, "hello" => 7_u32,
            }
            merges_a = [
              {"h", "e"},
              {"he", "l"},
              {"hel", "l"},
              {"hell", "o"},
            ]
            bpe_a = BPE.build do |b|
              b.vocab_and_merges(vocab_a, merges_a)
            end

            vocab_b = {"h" => 0_u32, "e" => 1_u32, "l" => 2_u32, "o" => 3_u32}
            bpe_b = BPE.build do |b|
              b.vocab_and_merges(vocab_b, [] of {String, String})
            end

            ids_a = bpe_a.tokenize("hello").map(&.id)
            ids_b = bpe_b.tokenize("hello").map(&.id)
            ids_a2 = bpe_a.tokenize("hello").map(&.id)
            ids_b2 = bpe_b.tokenize("hello").map(&.id)

            ids_a.should eq([7_u32])
            ids_b.should eq([0_u32, 1_u32, 2_u32, 2_u32, 3_u32])
            ids_a2.should eq(ids_a)
            ids_b2.should eq(ids_b)
          end
        end

        describe "FromFile" do
          it "loads BPE from vocab and merges files" do
            vocab_file = File.tempfile("vocab", ".json")
            vocab_file.print(%({"a": 0, "b": 1, "c": 2, "ab": 3}))
            vocab_file.close

            merges_file = File.tempfile("merges", ".txt")
            merges_file.print("#version: 0.2\na b")
            merges_file.close

            bpe = BPE.from_file(vocab_file.path, merges_file.path).build

            bpe.token_to_id("a").should eq(0_u32)
            bpe.token_to_id("b").should eq(1_u32)
            bpe.token_to_id("c").should eq(2_u32)
            bpe.token_to_id("ab").should eq(3_u32)

            tokens = bpe.tokenize("ab")
            tokens.should eq([Token.new(3_u32, "ab", {0_u32, 2_u32})])
          end

          it "raises MergeTokenOutOfVocabulary for unknown merge token" do
            vocab_file = File.tempfile("vocab_oov", ".json")
            vocab_file.print(%({"a": 0, "b": 1, "c": 2, "ab": 3}))
            vocab_file.close

            merges_file = File.tempfile("merges_oov", ".txt")
            merges_file.print("#version: 0.2\na b\na d")
            merges_file.close

            expect_raises(Tokens::Models::BPE::MergeTokenOutOfVocabulary, "d") do
              BPE.from_file(vocab_file.path, merges_file.path).build
            end
          end

          it "raises BadMerges for invalid merge line" do
            vocab_file = File.tempfile("vocab_bad", ".json")
            vocab_file.print(%({"a": 0, "b": 1, "c": 2, "ab": 3}))
            vocab_file.close

            merges_file = File.tempfile("merges_bad", ".txt")
            merges_file.print("#version: 0.2\na b\nc")
            merges_file.close

            expect_raises(Tokens::Models::BPE::BadMerges) do
              BPE.from_file(vocab_file.path, merges_file.path).build
            end
          end
        end

        describe "Serialization" do
          it "round-trips through JSON" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32, "ab" => 3_u32}
            merges = [{"a", "b"}]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.unk_token("<unk>")
              b.ignore_merges(true)
            end

            json = bpe.to_json
            restored = BPE.from_json(json)

            bpe.token_to_id("a").should eq(restored.token_to_id("a"))
            bpe.token_to_id("b").should eq(restored.token_to_id("b"))
            bpe.unk_token.should eq(restored.unk_token)
            bpe.ignore_merges?.should eq(restored.ignore_merges?)
            bpe.fuse_unk?.should eq(restored.fuse_unk?)
            bpe.byte_fallback?.should eq(restored.byte_fallback?)

            bpe.tokenize("ab").should eq(restored.tokenize("ab"))
          end

          it "handles tokens with spaces" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b c d" => 2_u32, "ab c d" => 3_u32}
            merges = [{"a", "b c d"}]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.unk_token("<unk>")
              b.ignore_merges(true)
            end

            json = bpe.to_json
            restored = BPE.from_json(json)

            bpe.tokenize("ab c d").should eq(restored.tokenize("ab c d"))
          end

          it "serializes ignore_merges=true" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
              b.ignore_merges(true)
            end

            bpe.ignore_merges?.should be_true
            json = bpe.to_json
            restored = BPE.from_json(json)
            restored.ignore_merges?.should be_true
          end

          it "serializes ignore_merges=false" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32}
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, [] of {String, String})
              b.unk_token("<unk>")
            end

            bpe.ignore_merges?.should be_false
            json = bpe.to_json
            restored = BPE.from_json(json)
            restored.ignore_merges?.should be_false
          end
        end

        describe "OrderedVocabIter" do
          it "iterates vocab in sorted ID order" do
            bpe = BPE.new({"a" => 0_u32, "b" => 1_u32, "c" => 2_u32, "ab" => 3_u32}, [] of {String, String})
            ordered = bpe.vocab_as_ordered_json
            ordered.should eq(%({"a":0,"b":1,"c":2,"ab":3}))
          end

          it "handles vocab with ID gaps" do
            bpe = BPE.new({"Hi" => 0_u32, "There" => 2_u32}, [] of {String, String})
            ordered = bpe.vocab_as_ordered_json
            ordered.should eq(%({"Hi":0,"There":2}))
          end
        end

        describe "Model serialization" do
          it "serializes BPE matching upstream format" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32, "ab" => 3_u32}
            merges = [{"a", "b"}]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.unk_token("<unk>")
              b.ignore_merges(true)
            end

            json = bpe.to_json
            expected = %({"type":"BPE","dropout":null,"unk_token":"<unk>","continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":true,"vocab":{"<unk>":0,"a":1,"b":2,"ab":3},"merges":[["a","b"]]})
            json.should eq(expected)
          end

          it "round-trips through JSON" do
            vocab = {"<unk>" => 0_u32, "a" => 1_u32, "b" => 2_u32, "ab" => 3_u32}
            merges = [{"a", "b"}]
            bpe = BPE.build do |b|
              b.vocab_and_merges(vocab, merges)
              b.unk_token("<unk>")
              b.ignore_merges(true)
            end

            json = bpe.to_json
            restored = BPE.from_json(json)

            bpe.token_to_id("a").should eq(restored.token_to_id("a"))
            bpe.tokenize("ab").should eq(restored.tokenize("ab"))
          end

          it "deserializes legacy format without type field" do
            legacy = %({"dropout":null,"unk_token":"<unk>","continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":true,"vocab":{"<unk>":0,"a":1,"b":2,"ab":3},"merges":["a b"]})
            bpe = BPE.from_json(legacy)
            bpe.token_to_id("a").should eq(1_u32)
            bpe.tokenize("ab").should eq([Token.new(3_u32, "ab", {0_u32, 2_u32})])
          end

          it "raises on invalid legacy merges" do
            invalid = %({"type":"BPE","dropout":null,"unk_token":null,"continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":false,"vocab":{"a":0,"b":1},"merges":["a b c"]})
            expect_raises(Tokens::Models::BPE::BadMerges) do
              BPE.from_json(invalid)
            end
          end
        end

        describe "BpeTrainer" do
          it "trains a basic BPE model" do
            word_counts = {
              "roses"   => 1_u64,
              "are"     => 2_u64,
              "red"     => 1_u64,
              "voilets" => 1_u64,
              "blue"    => 1_u64,
              "BERT"    => 1_u64,
              "is"      => 2_u64,
              "big"     => 1_u64,
              "and"     => 1_u64,
              "so"      => 1_u64,
              "GPT-2"   => 1_u64,
            }

            trainer = BpeTrainer.builder
              .show_progress(false)
              .min_frequency(2_u64)
              .build

            model = BPE.builder.build
            trainer.do_train(word_counts, model)

            expected_vocab = {
              "-"   => 0_u32,
              "2"   => 1_u32,
              "B"   => 2_u32,
              "E"   => 3_u32,
              "G"   => 4_u32,
              "P"   => 5_u32,
              "R"   => 6_u32,
              "T"   => 7_u32,
              "a"   => 8_u32,
              "b"   => 9_u32,
              "d"   => 10_u32,
              "e"   => 11_u32,
              "g"   => 12_u32,
              "i"   => 13_u32,
              "l"   => 14_u32,
              "n"   => 15_u32,
              "o"   => 16_u32,
              "r"   => 17_u32,
              "s"   => 18_u32,
              "t"   => 19_u32,
              "u"   => 20_u32,
              "v"   => 21_u32,
              "re"  => 22_u32,
              "are" => 23_u32,
              "is"  => 24_u32,
            }
            model.vocab.should eq(expected_vocab)

            expected_merges = {
              {17_u32, 11_u32} => {0_u32, 22_u32},
              {8_u32, 22_u32}  => {1_u32, 23_u32},
              {13_u32, 18_u32} => {2_u32, 24_u32},
            }
            model.merges.should eq(expected_merges)
          end

          it "respects max_token_length" do
            word_counts = {
              "sin" => 2_u64,
              "Sin" => 2_u64,
              "Lon" => 2_u64,
              "Ano" => 2_u64,
              "짧은한" => 2_u64,
              "긴한글" => 2_u64,
              "短字符" => 2_u64,
              "长字符" => 2_u64,
              "短い文" => 2_u64,
              "長い文" => 2_u64,
              "so"  => 2_u64,
              "GP"  => 2_u64,
            }

            trainer = BpeTrainer.builder
              .max_token_length(2_i32)
              .show_progress(false)
              .min_frequency(0_u64)
              .build

            model = BPE.builder.build
            trainer.do_train(word_counts, model)

            expected_vocab = {
              "A"  => 0_u32,
              "G"  => 1_u32,
              "L"  => 2_u32,
              "P"  => 3_u32,
              "S"  => 4_u32,
              "i"  => 5_u32,
              "n"  => 6_u32,
              "o"  => 7_u32,
              "s"  => 8_u32,
              "い"  => 9_u32,
              "字"  => 10_u32,
              "文"  => 11_u32,
              "短"  => 12_u32,
              "符"  => 13_u32,
              "長"  => 14_u32,
              "长"  => 15_u32,
              "글"  => 16_u32,
              "긴"  => 17_u32,
              "은"  => 18_u32,
              "짧"  => 19_u32,
              "한"  => 20_u32,
              "in" => 21_u32,
              "い文" => 22_u32,
              "字符" => 23_u32,
              "An" => 24_u32,
              "GP" => 25_u32,
              "Lo" => 26_u32,
              "so" => 27_u32,
              "긴한" => 28_u32,
              "은한" => 29_u32,
            }
            model.vocab.should eq(expected_vocab)
          end
        end
      end
    end
  end
end
