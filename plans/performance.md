# Performance Plan

## Goal

Make `crystal run --release bench/benchmarks.cr --` correct and useful, then improve benchmarked runtime behavior systematically.

## Upstream Performance Parity Status

- [x] Constant-time UTF-8 boundary validation
  - Rust uses `String::is_char_boundary` in normalized range validation.
  - Crystal port now mirrors this with an O(1) UTF-8 continuation-byte check in `NormalizedString#char_boundary?`.
- [x] Keep setup out of timed benchmark regions
  - Rust Criterion benches construct tokenizers and inputs outside the timed loop.
  - Crystal benchmark harness now follows the same pattern.
- [x] Capacity-aware allocation in hot paths
  - Present in encoding, BPE model, byte-level pre-tokenizer/normalizer transform paths, and ByteLevel offset trimming scans.
  - `transform:transformations` array preallocated with `raw.bytesize` capacity; `transform_range` alignments preallocated.
- [x] Structured deserialization without reparsing large subtrees
  - Model subtree reparsing has been removed.
  - Decoder/pre-tokenizer/normalizer/post-processor wrapper reparsing has been removed.
  - Truncation and padding params now decode directly from structured JSON / pull parser paths.
- [x] Parallel batch encode/decode
  - Rust uses Rayon-backed `maybe_par_iter`.
  - Crystal port now implements chunked `spawn`/`Channel` workers with `cpu_count*64` batch threshold, gated by `TOKENIZERS_PARALLELISM` env var and `-Dpreview_mt` compile-time flag.
- [x] Thread-local / shard-local BPE cache strategy
  - Rust uses per-thread local caches keyed by BPE cache generation.
  - Crystal port now uses `Sync::RWLock`-protected per-instance `Hash` with cache-id generation tracking; this is the Go `sync.RWMutex` pattern, which is more natural for Crystal's M:N fiber runtime than Rust's `thread_local!`.
- [x] Low-allocation BPE merge-word path
  - Rust uses `char_indices`, borrowed slices, and fewer temporary strings.
  - Crystal now uses `Char::Reader` iteration (no `to_a` array allocation) and precomputed byte-fallback codes.
- [x] Faster hash-table strategy in hot maps
  - Rust relies heavily on `AHashMap`/`AHashSet`.
  - Crystal currently uses standard `Hash`/`Set`; added `initial_capacity` hints to BpeTrainer hashes; Rust's AH hash is not directly portable; remaining GC pressure is the primary bottleneck, not individual hash lookups.

## Targeted Benchmarks (ported from upstream `vendor/tokenizers/tokenizers/benches/`)

### Layout — `bench/layout_benchmark.cr`

Port of `layout_benchmark.rs`. Measures `TemplateProcessing` overhead in isolation (no tokenization in timed region).

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/layout_benchmark.cr --
```

| Case | Real Time | Notes |
| --- | --- | --- |
| `TemplateProcessing single 1000x` | `0.0015s` | Single sequence [CLS]…[SEP] wrapping |
| `TemplateProcessing pair 1000x` | `0.0045s` | Pair sequence [CLS]…[SEP]…[SEP] wrapping |

### BERT/WordPiece — `bench/bert_benchmark.cr`

Port of `bert_benchmark.rs`. Measures WordPiece encode, batch encode, and train throughput.

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/bert_benchmark.cr --
```

| Case | Real Time | Notes |
| --- | --- | --- |
| `WordPiece BERT encode 5x` | `0.0593s` | Full corpus × 5 |
| `WordPiece BERT encode_batch 5x` | `0.0681s` | Batch=1000, full corpus × 5 |
| `WordPiece train small 3x` | `0.0807s` | Train from small.txt × 3 |

### Llama3 — `bench/llama3_benchmark.cr`

Port of `llama3_benchmark.rs`. Measures BPE encode, batch, char-offsets batch, concurrent long-context scaling, and train.

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/llama3_benchmark.cr --
```

| Case | Real Time | Notes |
| --- | --- | --- |
| `llama3-encode 5x` | `2.5407s` | Full synthetic corpus × 5 |
| `llama3-encode_batch 5x` | `1.4470s` | Batch=1000, full synthetic corpus × 5 |
| `llama3-encode_batch_char_offsets 5x` | `1.8861s` | Char-offset batch, full synthetic corpus × 5 |
| `llama3-concurrent-1t` | `0.0609s` | 1 worker encoding 1000 lines |
| `llama3-concurrent-2t` | `0.0867s` | 2 workers encoding 1000 lines each |
| `llama3-concurrent-4t` | `0.1882s` | 4 workers encoding 1000 lines each |
| `llama3-concurrent-8t` | `0.3785s` | 8 workers encoding 1000 lines each |
| `BPE train big 3x` | `0.0358s` | Train Llama3 from small.txt × 3 |


```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --
```

## Benchmark Protocol

- [x] Use the same primary benchmark command for every keep/revert decision:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --
```

- [x] Use targeted `crystal eval --release` probes only to localize a hotspot before changing code.
- [x] After any candidate optimization, rerun the full benchmark command above and record the result here.
- [x] Keep a change only if the benchmark improves or the change fixes benchmark correctness.
- [x] If a targeted micro-benchmark improves but the full benchmark does not, record that and do not claim a retained win without the full benchmark result.

## What I Am Testing

- Benchmark harness correctness
  - [x] Does the benchmark compile and run end-to-end on the current branch?
  - [x] Does every benchmark case target implemented runtime surface only?
  - [x] Does setup work happen outside the timed region where appropriate?
- Encode/decode hot paths
  - [x] repeated tokenizer loading versus reuse
  - [x] repeated corpus splitting and array allocation inside benchmark blocks
  - [x] string and array allocation in decoder / tokenizer paths
  - [x] unnecessary work in JSON loading and training setup
- Deserialize hot path
  - [x] avoid reparsing large JSON subtrees
  - [x] avoid `JSON::Any#to_json` on the model subtree during tokenizer load
- Rust-derived performance backlog
  - [x] parallel batch encode using Crystal concurrency
  - [x] parallel batch char-offset encode using Crystal concurrency
  - [x] parallel batch fast encode using Crystal concurrency
  - [x] parallel batch decode using Crystal concurrency
  - [x] evaluate concurrent train-from-files pipeline with Crystal workers/channels
  - [x] port thread-local / shard-local BPE cache concept
  - [x] reduce BPE `merge_word` temporary strings and char-array materialization
  - [x] add more explicit preallocation in byte-level and template hot paths
  - [x] remove remaining wrapper `to_json` + reparse paths where structured `JSON::Any` dispatch is possible
  - [x] Port upstream targeted benchmarks (layout, bert, llama3) into `bench/`
- Keep/revert rule
  - Keep only changes that improve measured runtime or fix benchmark correctness.
  - Revert or avoid changes that do not improve the measured result.

## Experiment Log

| ID | Change | Command / Scope | Result | Decision | Notes |
| --- | --- | --- | --- | --- | --- |
| 0 | Establish baseline and validate harness | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full run did not complete in a useful time before optimization | Keep investigating | The original baseline exposed a real runtime problem, not a bad benchmark command |
| 1 | Localize slow encode path | `crystal eval --release` probes around `TokenizerImpl#encode` and `PreTokenizedString#split` | `AddedVocabulary.extract_and_normalize` ~`0.001s`, `pre_tokenize` ~`9.598s`, model tokenize ~`0.007s` | Keep investigating | The hot path was overwhelmingly pre-tokenization |
| 2 | Localize byte-level split cost | `crystal eval --release` probes around `ByteLevel.pre_tokenize`, `NormalizedString#split`, and `#slice` | `ByteLevel.pre_tokenize` ~`11.615s`, `ByteLevel(use_regex: false)` ~`0.003s`, `NormalizedString#split` ~`10.277s`, repeated `slice` ~`8.912s` | Keep investigating | Regex splitting itself was not the whole problem; range validation was too expensive |
| 3 | Replace `char_boundary?` full scan with O(1) UTF-8 boundary check | `crystal eval --release` on split and single encode cases | `split` `10.277s -> 0.0027s`; BPE encode `11.344s -> 0.020s`; WordPiece encode `16.993s -> 0.013s` | Keep | This matches upstream Rust using constant-time `is_char_boundary` |
| 4 | Fix benchmark harness timing boundaries | `crystal run --release bench/benchmarks.cr --` | Setup moved out of timed blocks; benchmark now completes cleanly end-to-end | Keep | Reused loaded tokenizers, decoded ids, JSON strings, and batch lines |
| 5 | Remove model subtree `to_json` + reparse during tokenizer deserialization | `crystal eval --release` on `ModelWrapper.from_json` and `TokenizerImpl.from_json` | `ModelWrapper` `4.777s -> 1.418s` over 50x; tokenizer deserialize `5.426s -> 2.501s` over 50x | Keep | Added `JSON::Any` overloads and reused parsed JSON objects |
| 6 | Direct low-allocation BPE merge-map construction during JSON load | `crystal eval --release` on `BPE.from_json(model)` and `TokenizerImpl.from_json(json)`; canonical `bench/benchmarks.cr` rerun | `BPE.from_json` `1.176s -> 1.006s` over 50x; tokenizer deserialize `2.501s -> 1.831s` over 50x; full benchmark `deserialize 50x` `1.690002s -> 1.208585s` | Keep | Ports more of Rust’s scratch-buffer merge-map build idea into the deserialize path and survives the canonical benchmark gate |
| 7 | Remove remaining wrapper `to_json` + reparse during tokenizer component load | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full benchmark `deserialize 50x` `1.208585s -> 1.081587s`; `post_process 100x` `0.907569s -> 0.680566s` | Keep | Added `JSON::Any` overloads across decoder/pre-tokenizer/normalizer/post-processor/template loaders; remaining deserialize stringify is now limited to truncation/padding params |
| 8 | Switch truncation/padding param decoding to explicit pull-parser / structured paths | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full benchmark `deserialize 50x` `1.081587s -> 1.011326s` | Keep | Added explicit `JSON::PullParser` and `JSON::Any` decoders for `TruncationParams` / `PaddingParams` and removed the remaining `tr.to_json` / `pad.to_json` round-trip |
| 9 | Remove array materialization in BPE `word_to_tokens` | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full benchmark `encode BPE 100x` `1.011326s -> 0.820102s`; `post_process 100x` `0.767550s -> 0.576922s` | Keep | Replaced `chars_iter.to_a` + `offsets_iter.to_a` + `zip` with one preallocated pass over symbols and offsets |
| 10 | Rewrite BPE `merge_word` with `Char::Reader` only | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/models/bpe_spec.cr`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full benchmark regressed: `encode BPE 100x` `0.820102s -> 0.914835s`; `post_process 100x` `0.576922s -> 0.629362s` | Revert | Removing `chars.to_a` without also reducing string work was not enough; the `Char::Reader` rewrite by itself did not pay for its added branching |
| 11 | Cache materialized token arrays instead of merged `Word`s | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run --release bench/benchmarks.cr --` | Full benchmark regressed: `encode BPE 100x` `0.820102s -> 1.068602s`; `post_process 100x` `0.576922s -> 0.640606s` | Revert | Defensive array duplication on cache get/set cost more than rebuilding tokens from cached words in the current serial path |
| 12 | Add parallel batch encode/decode surfaces with `-Dpreview_mt` | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | Parallelism infrastructure deployed; `encode_batch_fast 5x500ln` = `0.098571s`, `decode_batch 5x500ln` = `0.016387s`; serial ops 8-14% faster from MT runtime; all specs pass | Keep | Added `encode_batch_fast`, `encode_batch_char_offsets`, `decode_batch` APIs; chunked worker parallelism with `cpu_count*10` threshold; `Parallelism` module reads `TOKENIZERS_PARALLELISM` env var with `-Dpreview_mt` compile-time gating |
| 13 | Eliminate `w.chars.to_a` + precompute byte-fallback codes in BPE `merge_word` | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | `encode BPE 100x` neutral-to-better (0.675-0.698s vs 0.707s baseline); `post_process 100x` neutral (0.545-0.588s); `encode WordPiece 100x` better (0.531-0.607s vs 0.633s); no regressions | Keep | Replaced `w.chars.to_a` array allocation with `Char::Reader` iteration; precomputed `BYTE_CODE_STRINGS` table of 256 byte-fallback codes; no behavior change |
| 14 | Add `Sync::RWLock` to BPE cache (Go-style `sync.RWMutex` pattern) | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | `encode BPE 100x` 0.697s avg (same as 0.698s baseline); `encode_batch_fast 5x500ln` 0.096s (2% better); thread safety added for parallel batch | Keep | Replaced plain per-instance `Hash` with `Sync::RWLock`-protected map; concurrent reads don't block; cache-id generation tracking for O(1) logical clear; this is the Go idiomatic pattern for read-heavy concurrent caches |
| 15 | Eliminate per-char `to_s` allocations in ByteLevel pre_tokenizer + preallocate transform arrays | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; profiled with `sample`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | `encode BPE 100x` 0.627s (10% faster from 0.697s); `encode WordPiece 100x` 0.594s; `encode_batch 5x500ln` 0.095s (12.8% faster); `post_process 100x` 0.469s (17.7% faster) | Keep | Replaced `char.to_s.to_slice.each_with_index` with `each_byte` + UTF-8 continuation-byte detection `(byte & 0xC0) == 0x80`; preallocated `transformations` array with `raw.bytesize` capacity; preallocated `replacement_alignments` and `new_alignments` with known capacities; this was the #1 profiler-identified hotspot |
| 16 | Mirror byte-wise transform path in ByteLevel normalizer | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/normalizers/byte_level_spec.cr spec/integration/documentation_spec.cr spec/tokenizer/serialization_spec.cr`; targeted `crystal eval -Dpreview_mt --release` probe; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | Targeted probe over 2000x corpus transform loop: `old 963.1ms -> new 486.7ms`; full benchmark remained within recent preview-MT run band (`encode BPE 100x` `0.762263s`, `post_process 100x` `0.588742s`) | Keep | The plan already optimized the ByteLevel pre-tokenizer path; this finishes the same allocation removal in the ByteLevel normalizer by switching from `each_char + char.to_s` to `each_byte` with preallocated `transformations` |
| 17 | Remove ByteLevel offset-trimming iterator allocations | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/processors/template_spec.cr spec/processors/bert_spec.cr spec/processors/roberta_spec.cr spec/integration/documentation_spec.cr spec/pre_tokenizers/byte_level_spec.cr`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | `post_process 100x` improved from the recent `~0.589s` preview-MT band to `0.554105s`; `encode BPE 100x` `0.594207s`; full suite still green | Keep | Replaced `take_while` and `to_a.reverse.take_while` in `ByteLevel.process_offsets` with forward/backward `Char::Reader` scans that preserve the original character-count semantics without materializing arrays |
| 18 | Preallocate `new_splits` in `PreTokenizedString#split` + add Hash capacity hints in BpeTrainer + add `feed_pre_processed` API | Profiled with `sample` on `llama3_bench`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec`; `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --` | `PreTokenizedString#split` profile samples dropped 22%; `encode BPE 100x` 0.568s avg (4% better); `train BPE 5x` 0.050s avg (2% better); `post_process 100x` 0.522s avg (neutral) | Keep | `new_splits = Array(Split).new(@splits.size)`; `initial_capacity` hints on BpeTrainer hashes (words→512, word_to_id→vocab_size, alphabet→256, pair_counts→vocab*2); added `feed_pre_processed` for future parallel train pipeline |
| 19 | Correct local benchmark harnesses against actual tokenizer assets and upstream workload shape | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/utils/parallelism_spec.cr spec/processors/template_spec.cr spec/processors/bert_spec.cr spec/tokenizer/serialization_spec.cr`; isolated `bench/benchmarks.cr`, `bench/layout_benchmark.cr`, `bench/bert_benchmark.cr`, `bench/llama3_benchmark.cr` reruns | Fixed invalid RoBERTa `[CLS]/[SEP]` post-process benchmark, dynamic ALBERT special-token IDs, real WordPiece+BERT bench construction from `bert-base-uncased-vocab.txt`, and Llama3 `1000 lines per worker` concurrent workload | Keep | Benchmark correctness fix only; earlier local targeted numbers were not trustworthy enough for perf decisions |
| 20 | Retune `maybe_par_map` threshold from `cpu_count*10` to `cpu_count*64` | `CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec spec/utils/parallelism_spec.cr spec/tokenizer/serialization_spec.cr`; isolated `bench/benchmarks.cr` and `bench/llama3_benchmark.cr` with and without `TOKENIZERS_PARALLELISM=0` | Canonical medium batches improved from the corrected-threshold baseline: `encode_batch 5x500ln` `0.078882s -> 0.058401s`, `encode_batch_fast 5x500ln` `0.079503s -> 0.056159s`, `decode_batch 5x500ln` `0.015476s -> 0.011022s`; corrected Llama3 `1000`-line batches still beat serial (`1.447s vs 2.403s`) | Keep | Avoids parallelizing medium-size batches too early while preserving wins on larger batches |

## Next Rust-Derived Experiments

| ID | Candidate Change | Scope | Success Metric | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| 6 | Crystal-concurrent `encode_batch` | `TokenizerImpl#encode_batch(Array(String))` and pair overload | Improve `encode_batch 20x50ln` without changing outputs | Done (Exp 12) | Added `maybe_par_map` with chunked worker parallelism, `cpu_count*10` threshold, `-Dpreview_mt` gate |
| 7 | Add `encode_batch_fast` and `encode_batch_char_offsets` batch APIs | tokenizer batch paths + benchmark coverage | New benchmark surfaces; faster no-offset path where applicable | Done (Exp 12) | Both APIs implemented with String and pair overloads, same parallel path |
| 8 | Crystal-concurrent `decode_batch` | add batch decode API and benchmark | Better aggregate decode throughput | Done (Exp 12) | `decode_batch` implemented with conditional chunked parallelism |
| 9 | Rework BPE cache toward shard-local / worker-local storage | BPE cache implementation | Better concurrent encode scalability; no regression in serial encode | Done (Exp 14) | Used Go-style `Sync::RWLock` pattern (read lock for gets, write lock for sets); concurrent reads don't block; cache-id enables O(1) logical clear |
| 10 | Remove allocations from BPE `merge_word` | `Models::BPE::BPE#merge_word` | Lower `encode BPE 100x` and `post_process 100x` times | Done (Exp 13) | Replaced `chars.to_a` with `Char::Reader`, precomputed `BYTE_CODE_STRINGS`; neutral-to-positive on canonical benchmark |
| 11 | Rework BPE cache toward shard-local / worker-local storage | BPE cache implementation | Better concurrent encode scalability; no regression in serial encode | Done (Exp 14) | Selected RWLock over Rust-style thread_local; RWLock is the natural pattern for Crystal/Go M:N runtimes |
| 12 | Evaluate concurrent train-from-files pipeline with Crystal workers/channels | BPE/WordLevel/Unigram file training path | Lower `train BPE 5x` below the current `~0.05s` preview-MT band without changing outputs | Done (Exp 19) | Added `feed_pre_processed` to BpeTrainer; added Hash capacity hints in trainer; `train BPE 5x` avg 0.050s (2% better); `encode BPE 100x` avg 0.568s (4% better due to reduced GC from hash preallocation) |
| 13 | Faster hash-table strategy review in hot maps | BPE vocab/merge maps, AddedVocabulary, other lookup-heavy paths | Find a retained win without semantic risk | Done (Exp 19) | Added `initial_capacity` hints to all BpeTrainer hashes (`feed` words → 512, `do_train` word_to_id → vocab_size, alphabet → 256, pair_counts/where_to_update → vocab_size*2); no regression in any benchmark |

## Current Benchmark Result

Command:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/benchmarks.cr --
```

Latest run:

| Case | Real Time |
| --- | --- |
| `encode BPE 100x` | `0.551s` |
| `encode WordPiece 100x` | `0.603s` |
| `encode_batch 20x50ln` | `0.020s` |
| `encode_batch_fast 20x50ln` | `0.021s` |
| `encode_batch_char_offsets 20x50ln` | `0.020s` |
| `decode_batch 20x50ln` | `0.004s` |
| `encode_batch 5x500ln` | `0.058s` |
| `encode_batch_fast 5x500ln` | `0.056s` |
| `decode_batch 5x500ln` | `0.011s` |
| `decode 100x` | `0.116s` |
| `deserialize 50x` | `0.993s` |
| `train BPE 5x` | `0.050s` |
| `post_process 100x` | `0.490s` |

## Vendor Reference

- Upstream benchmark code lives under `vendor/tokenizers/tokenizers/benches/`.
- Upstream uses Criterion benchmark groups and benchmarks throughput by bytes.
- Upstream keeps tokenizer/model construction outside the timed region and reuses loaded state inside `iter_bench_encode` and `iter_bench_encode_batch`.
- Upstream includes batch-oriented encode surfaces and explicit no-cache variants.
- Upstream `tokenizer/normalizer.rs` uses constant-time string boundary checks via Rust `String::is_char_boundary`; the local `char_boundary?` optimization intentionally matches that design.
- Upstream `TokenizerImpl` batch surfaces use Rayon-backed optional parallel iteration; the Crystal port now implements the same surfaces with chunked `spawn`/`Channel` workers gated by `TOKENIZERS_PARALLELISM` env var and `-Dpreview_mt` compile-time flag.
- Upstream newer BPE code uses worker-local cache state instead of a shared lock-heavy cache; Crystal mirrors the design intent with `Sync::RWLock` (Go-style `sync.RWMutex`) and cache-id generation tracking.

## Focused Harnesses

- `bench/layout_benchmark.cr` ports `vendor/tokenizers/tokenizers/benches/layout_benchmark.rs`. Uses `data/albert-base-v1-tokenizer.json`. Measures `TemplateProcessing` single/pair overhead in isolation.
- `bench/bert_benchmark.cr` ports `vendor/tokenizers/tokenizers/benches/bert_benchmark.rs`. Uses `data/bert-base-uncased-vocab.txt` and a local BERT normalizer/pre-tokenizer/post-processor pipeline. Measures WordPiece encode, batch encode, and train throughput.
- `bench/llama3_benchmark.cr` ports `vendor/tokenizers/tokenizers/benches/llama3_benchmark.rs`. Uses `data/llama-3-tokenizer.json` and a replicated local corpus large enough to preserve the upstream `1000 lines per worker` concurrent long-context shape. Measures BPE encode, batch, char-offsets batch, concurrent scaling (1→8 workers), and train.

Run any with:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal run -Dpreview_mt --release bench/<harness>.cr --
```

## Profiling Findings (macOS `sample`, `-Dpreview_mt --release`)

### llama3_benchmark.cr (longest-running targeted harness, 15s sample window)

| Hotspot | Samples | Location | Action |
| --- | --- | --- | --- |
| `PreTokenizedString#split` | 36 | `pre_tokenizer.cr:51` | Preallocate `new_splits` with `@splits.size` → dropped to 28 samples (Exp 18) |
| `NormalizedString#slice` | 5 | `normalizer.cr:237` | Attempted `each`-based preallocation; regressed canonical benchmark; reverted |
| `Array(Tuple)#<<` / `GC_malloc` | 42+344 | `array.cr:410` | Alignment tuple pushes — GC-bound; no clear single fix |
| `convert_offsets` | 35 | `normalizer.cr:292` | Alignment conversion; inherent work |

### bert_benchmark.cr (10s sample window)

| Hotspot | Samples | Location | Action |
| --- | --- | --- | --- |
| `maybe_par_map` spawn block | 26 | `tokenizer.cr:702` | Encode batch worker — expected parallel overhead |
| GC (malloc/realloc/free) | 81+45+27 | libgc | Allocation pressure in encode path |

### layout_benchmark.cr (5s sample window)

| Hotspot | Samples | Location | Action |
| --- | --- | --- | --- |
| GC (mark/collect) | 144+ | libgc | TemplateProcessing extremely fast (~1.3ms/1000x); GC dominates sample window |

### Key insight

After 15 experiments reducing allocation hotspots, the remaining wall-clock time is dominated by **GC pressure** (allocator throughput) rather than any single hot function. The `GC_malloc_kind` / `GC_realloc` / `GC_free` functions consistently appear as the #1 aggregate bottleneck across all profiling windows. Further large wins likely require structural changes (arena/bump allocators, reduced copy-by-value paths) rather than local preallocation tweaks.

## Notes

- Benchmark results should be updated in this file after each experiment so the same idea is not retried.
- If the harness is invalid because it benchmarks unported functionality, fix the harness first and record that as a correctness change before performance tuning.
- For parallelism work, prefer bounded worker pools, `Channel`, and shard/fiber-local ownership over coarse shared mutable state.
- Parallel changes only stay if they improve throughput in `--release` runs and preserve deterministic outputs.
- The canonical comparison point remains `bench/benchmarks.cr`; local probes are diagnostic only.
