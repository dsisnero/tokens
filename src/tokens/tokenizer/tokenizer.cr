module Tokens
  class DecodeStreamError < Exception
    getter token_id : UInt32
    getter expected_prefix : String
    getter actual_string : String

    def initialize(@token_id : UInt32, @expected_prefix : String, @actual_string : String)
      super("Invalid prefix encountered while decoding stream. Token ID: #{@token_id}, Expected prefix: '#{@expected_prefix}', Actual string: '#{@actual_string}'")
    end
  end

  module Normalizer
    abstract def normalize(normalized : NormalizedString) : Nil

    def to_json(json : JSON::Builder)
    end
  end

  module PreTokenizer
    abstract def pre_tokenize(pretokenized : PreTokenizedString) : Nil

    def to_json(json : JSON::Builder)
    end
  end

  module PostProcessor
    abstract def added_tokens(is_pair : Bool) : Int32

    abstract def process(
      encoding : Encoding,
      pair_encoding : Encoding?,
      add_special_tokens : Bool,
    ) : Encoding

    def to_json(json : JSON::Builder)
    end
  end

  module Decoder
    abstract def decode_chain(tokens : Array(String)) : Array(String)

    def decode(tokens : Array(String)) : String
      decode_chain(tokens).join
    end

    def to_json(json : JSON::Builder)
    end
  end

  module Trainer(ModelType)
    abstract def should_show_progress? : Bool
    abstract def train(model : ModelType) : Array(AddedToken)
  end

  class TokenizerImpl
    getter model : Model
    getter normalizer : Normalizer?
    getter pre_tokenizer : PreTokenizer?
    getter post_processor : PostProcessor?
    getter decoder : Decoder?
    getter added_vocabulary : AddedVocabulary
    getter truncation : TruncationParams?
    getter padding : PaddingParams?

    def initialize(@model : Model)
      @normalizer = nil
      @pre_tokenizer = nil
      @post_processor = nil
      @decoder = nil
      @added_vocabulary = AddedVocabulary.new
      @truncation = nil
      @padding = nil
    end

    def with_normalizer(normalizer : Normalizer?) : self
      @normalizer = normalizer
      @added_vocabulary.refresh_normalized_tokens(normalizer)
      self
    end

    def get_normalizer : Normalizer?
      @normalizer
    end

    def with_pre_tokenizer(pre_tokenizer : PreTokenizer?) : self
      @pre_tokenizer = pre_tokenizer
      self
    end

    def get_pre_tokenizer : PreTokenizer?
      @pre_tokenizer
    end

    def with_post_processor(post_processor : PostProcessor?) : self
      @post_processor = post_processor
      self
    end

    def get_post_processor : PostProcessor?
      @post_processor
    end

    def with_decoder(decoder : Decoder?) : self
      @decoder = decoder
      self
    end

    def get_decoder : Decoder?
      @decoder
    end

    def with_model(model : Model) : self
      @model = model
      self
    end

    def get_model : Model
      @model
    end

    def with_added_vocabulary(vocab : AddedVocabulary) : self
      @added_vocabulary = vocab
      self
    end

    def get_added_vocabulary : AddedVocabulary
      @added_vocabulary
    end

    def with_truncation(params : TruncationParams?) : self
      @truncation = params
      self
    end

    def get_truncation : TruncationParams?
      @truncation
    end

    def with_padding(params : PaddingParams?) : self
      @padding = params
      self
    end

    def get_padding : PaddingParams?
      @padding
    end

    def get_vocab(with_added_tokens : Bool = false) : Hash(String, UInt32)
      final_vocab = @model.vocab.dup
      if with_added_tokens
        added_vocab = @added_vocabulary.get_vocab
        added_vocab.each { |token, id| final_vocab[token] = id }
      end
      final_vocab
    end

    def get_vocab_size(with_added_tokens : Bool = false) : Int32
      if with_added_tokens
        get_vocab(true).size
      else
        @model.vocab_size.to_i32
      end
    end

    def token_to_id(token : String) : UInt32?
      @added_vocabulary.token_to_id(token, @model)
    end

    def id_to_token(id : UInt32) : String?
      @added_vocabulary.simple_id_to_token(id) || @model.id_to_token(id)
    end

    def set_encode_special_tokens(value : Bool)
      @added_vocabulary.set_encode_special_tokens(value)
    end

    def get_encode_special_tokens : Bool
      @added_vocabulary.get_encode_special_tokens
    end

    def add_special_tokens(tokens : Array(AddedToken)) : UInt64
      @added_vocabulary.add_special_tokens(tokens, @model, @normalizer)
    end

    def add_tokens(tokens : Array(AddedToken)) : UInt64
      @added_vocabulary.add_tokens(tokens, @model, @normalizer)
    end

    def encode_single_sequence(sequence : InputSequence, type_id : UInt32, offsets_type : OffsetType) : Encoding
      if raw = sequence.raw?
        pre_tokenized = @added_vocabulary.extract_and_normalize(@normalizer, raw)
        pre_tokenized = do_pre_tokenize(pre_tokenized)
        do_tokenize(pre_tokenized, type_id, nil, offsets_type)
      elsif pretokenized = sequence.pretokenized?
        encodings = pretokenized.map_with_index { |subseq, i|
          pre_tokenized = @added_vocabulary.extract_and_normalize(@normalizer, subseq)
          pre_tokenized = do_pre_tokenize(pre_tokenized)
          do_tokenize(pre_tokenized, type_id, i.to_u32, offsets_type)
        }
        Encoding.merge(encodings, false)
      else
        Encoding.new
      end
    end

    def encode(input : String, add_special_tokens : Bool = false) : Encoding
      sequence = InputSequence.new(input)
      encoding = encode_single_sequence(sequence, 0_u32, OffsetType::Byte)
      post_process(encoding, nil, add_special_tokens)
    end

    def encode(input : Tuple(String, String), add_special_tokens : Bool = false) : Encoding
      seq1 = InputSequence.new(input[0])
      seq2 = InputSequence.new(input[1])
      encoding = encode_single_sequence(seq1, 0_u32, OffsetType::Byte)
      pair_encoding = encode_single_sequence(seq2, 1_u32, OffsetType::Byte)
      post_process(encoding, pair_encoding, add_special_tokens)
    end

    def encode_fast(input : String, add_special_tokens : Bool = false) : Encoding
      sequence = InputSequence.new(input)
      encoding = encode_single_sequence(sequence, 0_u32, OffsetType::None)
      post_process(encoding, nil, add_special_tokens)
    end

    def encode_fast(input : Tuple(String, String), add_special_tokens : Bool = false) : Encoding
      seq1 = InputSequence.new(input[0])
      seq2 = InputSequence.new(input[1])
      encoding = encode_single_sequence(seq1, 0_u32, OffsetType::None)
      pair_encoding = encode_single_sequence(seq2, 1_u32, OffsetType::None)
      post_process(encoding, pair_encoding, add_special_tokens)
    end

    def encode_char_offsets(input : String, add_special_tokens : Bool = false) : Encoding
      sequence = InputSequence.new(input)
      encoding = encode_single_sequence(sequence, 0_u32, OffsetType::Char)
      post_process(encoding, nil, add_special_tokens)
    end

    def encode_char_offsets(input : Tuple(String, String), add_special_tokens : Bool = false) : Encoding
      seq1 = InputSequence.new(input[0])
      seq2 = InputSequence.new(input[1])
      encoding = encode_single_sequence(seq1, 0_u32, OffsetType::Char)
      pair_encoding = encode_single_sequence(seq2, 1_u32, OffsetType::Char)
      post_process(encoding, pair_encoding, add_special_tokens)
    end

    def decode(ids : Array(UInt32), skip_special_tokens : Bool = false) : String
      tokens = ids.compact_map { |id|
        token = @added_vocabulary.simple_id_to_token(id) || @model.id_to_token(id)
        if token && skip_special_tokens && @added_vocabulary.is_special_token(token)
          nil
        else
          token
        end
      }

      if decoder = @decoder
        decoder.decode(tokens)
      else
        tokens.join(" ")
      end
    end

    def decode_stream(skip_special_tokens : Bool = false) : DecodeStream
      DecodeStream.new(self, skip_special_tokens)
    end

    protected def do_normalize(normalized : NormalizedString) : NormalizedString
      if normalizer = @normalizer
        normalizer.normalize(normalized)
      end
      normalized
    end

    protected def do_pre_tokenize(pretokenized : PreTokenizedString) : PreTokenizedString
      if pre_tokenizer = @pre_tokenizer
        pre_tokenizer.pre_tokenize(pretokenized)
      end
      pretokenized
    end

    protected def do_tokenize(pretokenized : PreTokenizedString, type_id : UInt32, word_idx : UInt32?, offsets_type : OffsetType) : Encoding
      if trunc = @truncation
        if trunc.strategy != TruncationStrategy::OnlySecond || type_id != 0
          pretokenized.tokenize_with_limit(
            ->(normalized : NormalizedString) { @model.tokenize(normalized.get) },
            trunc.max_length.to_i32,
            trunc.direction
          )
        else
          pretokenized.tokenize(
            ->(normalized : NormalizedString) { @model.tokenize(normalized.get) }
          )
        end
      else
        pretokenized.tokenize(
          ->(normalized : NormalizedString) { @model.tokenize(normalized.get) }
        )
      end

      pretokenized.into_encoding(word_idx, type_id, offsets_type)
    end

    protected def post_process(encoding : Encoding, pair_encoding : Encoding?, add_special_tokens : Bool) : Encoding
      e1 = encoding
      e2 = pair_encoding

      if trunc = @truncation
        n_added = get_n_added_tokens(!e2.nil?)
        if add_special_tokens && n_added > 0
          params = TruncationParams.new(
            max_length: trunc.max_length - n_added.to_u64,
            strategy: trunc.strategy,
            stride: trunc.stride,
            direction: trunc.direction
          )
          e1, e2 = Tokens.truncate_encodings(e1, e2, params)
        else
          e1, e2 = Tokens.truncate_encodings(e1, e2, trunc)
        end
      end

      final = if processor = @post_processor
                processor.process(e1, e2, add_special_tokens)
              else
                encodings = if pe = e2
                              [e1, pe]
                            else
                              [e1]
                            end

                encodings.each_with_index do |enc, i|
                  enc.set_sequence_id(i.to_u64)
                  enc.overflowing.each { |o| o.set_sequence_id(i.to_u64) }
                  enc.set_type_ids(Array(UInt32).new(enc.length, i.to_u32))
                end

                Encoding.merge(encodings, false)
              end

      if pad = @padding
        target = case pad.strategy
                 when PaddingStrategy::Fixed
                   (pad.fixed_size || 0_u64).to_i32
                 else
                   final.length
                 end
        final.pad(target, pad.pad_id, pad.pad_type_id, pad.pad_token, pad.direction)
      end

      final
    end

    def get_n_added_tokens(is_pair : Bool) : Int32
      if processor = @post_processor
        processor.added_tokens(is_pair)
      else
        0
      end
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "version", "1.0"

        json.field "truncation" do
          if t = @truncation
            t.to_json(json)
          else
            json.null
          end
        end

        json.field "padding" do
          if p = @padding
            p.to_json(json)
          else
            json.null
          end
        end

        json.field "added_tokens" do
          @added_vocabulary.to_json(json)
        end

        json.field "normalizer" do
          if n = @normalizer
            n.to_json(json)
          else
            json.null
          end
        end

        json.field "pre_tokenizer" do
          if pt = @pre_tokenizer
            pt.to_json(json)
          else
            json.null
          end
        end

        json.field "post_processor" do
          if pp = @post_processor
            pp.to_json(json)
          else
            json.null
          end
        end

        json.field "decoder" do
          if d = @decoder
            d.to_json(json)
          else
            json.null
          end
        end

        json.field "model" do
          case model = @model
          when Models::BPE::BPE
            json.raw(ModelWrapper.new(model).to_json)
          when Models::WordPiece
            json.raw(ModelWrapper.new(model).to_json)
          when Models::WordLevel
            json.raw(ModelWrapper.new(model).to_json)
          when Models::Unigram::Unigram
            json.raw(ModelWrapper.new(model).to_json)
          else
            json.null
          end
        end
      end
    end

    def self.from_json(json_str : String) : self
      data = JSON.parse(json_str)
      raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
      obj = data.as_h

      version = obj["version"]?.try(&.as_s?)
      raise Exception.new("Unknown tokenizer version '#{version}'") unless version == "1.0"

      model_val = obj["model"]?
      raise Exception.new("Missing model") unless model_val
      model_json = model_val.to_json
      model = ModelWrapper.from_json(model_json).model.as(Model)
      tokenizer = new(model)

      if tr = obj["truncation"]?
        unless tr.raw.nil?
          params = TruncationParams.from_json(tr.to_json)
          tokenizer.with_truncation(params)
        end
      end

      if pad = obj["padding"]?
        unless pad.raw.nil?
          params = PaddingParams.from_json(pad.to_json)
          tokenizer.with_padding(params)
        end
      end

      if norm = obj["normalizer"]?
        unless norm.raw.nil?
          tokenizer.with_normalizer(NormalizerWrapper.from_json(norm.to_json).as(Normalizer))
        end
      end

      if pt = obj["pre_tokenizer"]?
        unless pt.raw.nil?
          tokenizer.with_pre_tokenizer(PreTokenizerWrapper.from_json(pt.to_json).as(PreTokenizer))
        end
      end

      if pp = obj["post_processor"]?
        unless pp.raw.nil?
          tokenizer.with_post_processor(PostProcessorWrapper.from_json(pp.to_json).as(PostProcessor))
        end
      end

      if dec = obj["decoder"]?
        unless dec.raw.nil?
          tokenizer.with_decoder(DecoderWrapper.from_json(dec.to_json).as(Decoder))
        end
      end

      added_tokens_arr = obj["added_tokens"]?.try(&.as_a?)
      if added_tokens_arr
        tokens = added_tokens_arr.map do |entry|
          AddedTokenWithId.from_json(entry.to_json)
        end
        tok_tokens = tokens.map do |atwi|
          t = atwi.token
          if t.normalized
            t.normalized(true)
          end
          t
        end
        tokenizer.add_tokens(tok_tokens)
      end

      tokenizer
    end
  end

  class Tokenizer
    getter inner : TokenizerImpl

    def initialize(model : Model)
      @inner = TokenizerImpl.new(model)
    end

    macro forward_to_inner
      {% for name in %w[with_normalizer get_normalizer with_pre_tokenizer get_pre_tokenizer
                       with_post_processor get_post_processor with_decoder get_decoder
                       with_model get_model with_added_vocabulary get_added_vocabulary
                       with_truncation get_truncation with_padding get_padding
                       get_vocab get_vocab_size token_to_id id_to_token
                       set_encode_special_tokens get_encode_special_tokens
                       add_special_tokens add_tokens encode encode_fast
                       encode_char_offsets decode decode_stream get_n_added_tokens
                       to_json from_json] %}
      def {{name.id}}(*args, **kwargs)
        @inner.{{name.id}}(*args, **kwargs)
      end
      {% end %}
    end

    forward_to_inner
  end

  class DecodeStream
    getter tokenizer : TokenizerImpl
    getter skip_special_tokens : Bool
    getter ids : Array(UInt32)
    getter prefix : String
    getter prefix_index : Int32

    def initialize(@tokenizer : TokenizerImpl, @skip_special_tokens : Bool)
      @ids = [] of UInt32
      @prefix = ""
      @prefix_index = 0
    end

    def step(id : UInt32) : String?
      if @prefix.empty? && !@ids.empty?
        new_prefix = @tokenizer.decode(@ids, @skip_special_tokens)
        if !new_prefix.ends_with?("�")
          @prefix = new_prefix
          @prefix_index = @ids.size
        end
      end

      @ids << id
      string = @tokenizer.decode(@ids, @skip_special_tokens)

      if string.bytesize > @prefix.bytesize && !string.ends_with?("�")
        if !string.starts_with?(@prefix)
          raise DecodeStreamError.new(@ids.last, @prefix, string)
        end

        new_text = string[@prefix.bytesize..]
        new_prefix_index = @ids.size - @prefix_index
        @ids = @ids[@prefix_index..]
        @prefix = @tokenizer.decode(@ids, @skip_special_tokens)
        @prefix_index = new_prefix_index
        new_text
      else
        nil
      end
    end
  end
end
