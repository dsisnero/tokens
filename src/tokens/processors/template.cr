require "json"

module Tokens
  module PostProcessors
    enum ProcessorSequence
      A
      B
    end

    struct Piece
      enum Kind
        Sequence
        SpecialToken
      end

      getter kind : Kind
      getter sequence_id : ProcessorSequence?
      getter special_token_id : String?
      getter type_id : UInt32

      def self.sequence(id : ProcessorSequence, type_id : UInt32) : Piece
        new(Kind::Sequence, id, nil, type_id)
      end

      def self.special_token(id : String, type_id : UInt32) : Piece
        new(Kind::SpecialToken, nil, id, type_id)
      end

      def initialize(@kind : Kind, @sequence_id : ProcessorSequence?, @special_token_id : String?, @type_id : UInt32)
      end

      def ==(other : self) : Bool
        @kind == other.kind &&
          @sequence_id == other.sequence_id &&
          @special_token_id == other.special_token_id &&
          @type_id == other.type_id
      end

      def to_json(json : JSON::Builder)
        json.object do
          case @kind
          when Kind::Sequence
            json.field "Sequence" do
              json.object do
                json.field "id", @sequence_id.not_nil!.to_s
                json.field "type_id", @type_id
              end
            end
          when Kind::SpecialToken
            json.field "SpecialToken" do
              json.object do
                json.field "id", @special_token_id.not_nil!
                json.field "type_id", @type_id
              end
            end
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
        obj = data.as_h

        if seq_val = obj["Sequence"]?.try(&.as_h?)
          id_str = seq_val["id"]?.try(&.as_s?) || raise(JSON::ParseException.new("Missing Sequence id", 0, 0))
          type_id = seq_val["type_id"]?.try(&.as_i?) || raise(JSON::ParseException.new("Missing Sequence type_id", 0, 0))
          seq = case id_str
                when "A" then ProcessorSequence::A
                when "B" then ProcessorSequence::B
                else          raise JSON::ParseException.new("Invalid Sequence id: #{id_str}", 0, 0)
                end
          Piece.sequence(seq, type_id.to_u32)
        elsif spe_val = obj["SpecialToken"]?.try(&.as_h?)
          id_str = spe_val["id"]?.try(&.as_s?) || raise(JSON::ParseException.new("Missing SpecialToken id", 0, 0))
          type_id = spe_val["type_id"]?.try(&.as_i?) || raise(JSON::ParseException.new("Missing SpecialToken type_id", 0, 0))
          Piece.special_token(id_str, type_id.to_u32)
        else
          raise JSON::ParseException.new("Unknown Piece variant", 0, 0)
        end
      end

      def self.parse(s : String) : self
        parts = s.split(':')

        if parts.size > 2
          raise ArgumentError.new("Cannot build Piece from string \"#{s}\"")
        end

        id_str = parts[0]
        type_id_str = parts[1]?

        piece = extract_id(id_str) || raise(ArgumentError.new("Cannot build Piece from string \"#{s}\""))

        if type_id_str
          begin
            type_id = type_id_str.to_u32
          rescue
            raise ArgumentError.new("Cannot build Piece from string \"#{s}\"")
          end
          piece = piece.with_type_id(type_id)
        end

        piece
      end

      def with_type_id(type_id : UInt32) : Piece
        if @kind == Kind::Sequence
          Piece.sequence(@sequence_id.not_nil!, type_id)
        else
          Piece.special_token(@special_token_id.not_nil!, type_id)
        end
      end

      private def self.extract_id(s : String) : self?
        if s.starts_with?("$")
          rest = s.byte_slice(1)
          return nil if rest.nil?
          case rest
          when ""
            Piece.sequence(ProcessorSequence::A, 0_u32)
          when "A", "a"
            Piece.sequence(ProcessorSequence::A, 0_u32)
          when "B", "b"
            Piece.sequence(ProcessorSequence::B, 0_u32)
          else
            begin
              type_id = rest.to_u32
              Piece.sequence(ProcessorSequence::A, type_id)
            rescue
              nil
            end
          end
        else
          Piece.special_token(s, 0_u32)
        end
      end
    end

    struct TemplateSpecialToken
      include JSON::Serializable

      getter id : String
      getter ids : Array(UInt32)
      getter tokens : Array(String)

      def initialize(@id : String, @ids : Array(UInt32), @tokens : Array(String))
        unless @ids.size == @tokens.size
          raise ArgumentError.new("ids and tokens must be of the same length")
        end
      end

      def self.from_tuple(tuple : Tuple(String, UInt32)) : self
        new(tuple[0], [tuple[1]], [tuple[0]])
      end
    end

    struct ProcTemplate
      getter pieces : Array(Piece)

      def initialize(@pieces : Array(Piece) = [] of Piece)
      end

      def self.parse(s : String) : self
        parts = s.split(' ')
        pieces = parts.map { |p| Piece.parse(p) }
        new(pieces)
      end

      def ==(other : self) : Bool
        @pieces == other.pieces
      end

      def to_json(json : JSON::Builder)
        json.array do
          @pieces.each do |piece|
            piece.to_json(json)
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected array", 0, 0) unless data.as_a?
        pieces = data.as_a.map do |item|
          Piece.from_json(item.to_json)
        end
        new(pieces)
      end
    end

    struct TokensMap
      getter map : Hash(String, TemplateSpecialToken)

      def initialize(@map = {} of String => TemplateSpecialToken)
      end

      def self.from_tuples(tuples : Array(Tuple(String, UInt32))) : self
        map = {} of String => TemplateSpecialToken
        tuples.each do |(id, val)|
          token = TemplateSpecialToken.from_tuple({id, val})
          map[id] = token
        end
        new(map)
      end

      def [](key : String) : TemplateSpecialToken?
        @map[key]?
      end

      def []?(key : String) : TemplateSpecialToken?
        @map[key]?
      end

      def has_key?(key : String) : Bool
        @map.has_key?(key)
      end

      def ==(other : self) : Bool
        @map == other.map
      end

      def to_json(json : JSON::Builder)
        json.object do
          @map.each do |key, token|
            json.field key do
              token.to_json(json)
            end
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
        map = {} of String => TemplateSpecialToken
        data.as_h.each do |key, value|
          map[key] = TemplateSpecialToken.from_json(value.to_json)
        end
        new(map)
      end
    end

    class TemplateProcessing
      include Tokens::PostProcessor

      getter single : ProcTemplate
      getter pair : ProcTemplate
      getter special_tokens : TokensMap
      getter added_single : Int32
      getter added_pair : Int32

      private def initialize(
        @single : ProcTemplate,
        @pair : ProcTemplate,
        @special_tokens : TokensMap,
        @added_single : Int32,
        @added_pair : Int32,
      )
      end

      def self.build(single : ProcTemplate, pair : ProcTemplate, special_tokens : TokensMap) : self
        validate(single, pair, special_tokens)

        added_single = count_added(single, special_tokens)
        added_pair = count_added(pair, special_tokens)

        new(single, pair, special_tokens, added_single, added_pair)
      end

      private def self.count_added(template : ProcTemplate, special_tokens : TokensMap) : Int32
        count = 0
        template.pieces.each do |piece|
          case piece.kind
          when Piece::Kind::Sequence
            # nothing
          when Piece::Kind::SpecialToken
            if id = piece.special_token_id
              if tok = special_tokens[id]?
                count += tok.ids.size
              end
            end
          end
        end
        count
      end

      private def self.validate(single : ProcTemplate, pair : ProcTemplate, special_tokens : TokensMap)
        # Check pair uses both sequences
        has_a = false
        has_b = false
        pair.pieces.each do |piece|
          if piece.kind == Piece::Kind::Sequence
            case piece.sequence_id
            when ProcessorSequence::A
              has_a = true
            when ProcessorSequence::B
              has_b = true
            end
          end
        end
        unless has_a && has_b
          raise ArgumentError.new("Template for `pair` must use both sequences")
        end

        # Check all special tokens exist
        missing = Set(String).new
        single.pieces.each do |piece|
          if id = piece.special_token_id
            missing << id unless special_tokens.has_key?(id)
          end
        end
        pair.pieces.each do |piece|
          if id = piece.special_token_id
            missing << id unless special_tokens.has_key?(id)
          end
        end

        unless missing.empty?
          raise ArgumentError.new("Missing SpecialToken(s) with id(s) `#{missing.to_a.sort.join(", ")}`")
        end
      end

      def added_tokens(is_pair : Bool) : Int32
        is_pair ? @added_pair : @added_single
      end

      def process(encoding : Tokens::Encoding, pair_encoding : Tokens::Encoding?, add_special_tokens : Bool) : Tokens::Encoding
        template = if pair_encoding
                     @pair
                   else
                     @single
                   end

        encodings = if pe = pair_encoding
                      [encoding, pe]
                    else
                      [encoding]
                    end

        apply_template(template, encodings, add_special_tokens)
      end

      private def apply_template(template : ProcTemplate, encodings : Array(Tokens::Encoding), add_special_tokens : Bool) : Tokens::Encoding
        final_encodings = [] of Tokens::Encoding

        template.pieces.each do |piece|
          case piece.kind
          when Piece::Kind::Sequence
            seq = piece.sequence_id.not_nil!
            idx = seq == ProcessorSequence::B ? 1 : 0
            enc = encodings[idx]
            enc.set_type_ids(Array(UInt32).new(enc.length, piece.type_id))
            enc.set_sequence_id(idx.to_u64)
            final_encodings << enc.copy
          when Piece::Kind::SpecialToken
            if add_special_tokens
              id = piece.special_token_id.not_nil!
              tok = @special_tokens[id].not_nil!
              len = tok.ids.size

              special_encoding = Tokens::Encoding.new(
                ids: tok.ids,
                type_ids: Array(UInt32).new(len, piece.type_id),
                tokens: tok.tokens,
                words: Array(UInt32?).new(len, nil),
                offsets: Array(Tuple(UInt32, UInt32)).new(len, {0_u32, 0_u32}),
                special_tokens_mask: Array(UInt32).new(len, 1_u32),
                attention_mask: Array(UInt32).new(len, 1_u32),
                overflowing: [] of Tokens::Encoding,
                sequence_ranges: {} of UInt64 => ::Range(UInt64, UInt64)
              )
              final_encodings << special_encoding
            end
          end
        end

        Tokens::Encoding.merge(final_encodings, false)
      end

      def ==(other : self) : Bool
        @single.pieces == other.single.pieces &&
          @pair.pieces == other.pair.pieces &&
          @special_tokens.map == other.special_tokens.map
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "type", "TemplateProcessing"
          json.field "single" do
            json.array do
              @single.pieces.each do |piece|
                piece.to_json(json)
              end
            end
          end
          json.field "pair" do
            json.array do
              @pair.pieces.each do |piece|
                piece.to_json(json)
              end
            end
          end
          json.field "special_tokens" do
            json.object do
              @special_tokens.map.each do |key, token|
                json.field key do
                  token.to_json(json)
                end
              end
            end
          end
        end
      end

      def self.from_json(json_str : String) : self
        data = JSON.parse(json_str)
        raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?

        obj = data.as_h

        single_arr = obj["single"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing single", 0, 0))
        pair_arr = obj["pair"]?.try(&.as_a?) || raise(JSON::ParseException.new("Missing pair", 0, 0))
        tokens_obj = obj["special_tokens"]?.try(&.as_h?) || raise(JSON::ParseException.new("Missing special_tokens", 0, 0))

        single_pieces = single_arr.map do |item|
          Piece.from_json(item.to_json)
        end
        pair_pieces = pair_arr.map do |item|
          Piece.from_json(item.to_json)
        end

        tokens_map = {} of String => TemplateSpecialToken
        tokens_obj.each do |key, value|
          tokens_map[key] = TemplateSpecialToken.from_json(value.to_json)
        end

        single = ProcTemplate.new(single_pieces)
        pair = ProcTemplate.new(pair_pieces)
        special_tokens = TokensMap.new(tokens_map)

        build(single: single, pair: pair, special_tokens: special_tokens)
      end
    end
  end
end
