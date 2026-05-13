require "json"

module Tokens
  class ModelWrapper
    include Model

    alias Wrapped = Models::BPE::BPE |
                    Models::WordPiece |
                    Models::WordLevel |
                    Models::Unigram::Unigram

    getter model : Wrapped

    def initialize(@model : Wrapped)
    end

    def tokenize(sequence : String) : Array(Token)
      @model.tokenize(sequence)
    end

    def token_to_id(token : String) : UInt32?
      @model.token_to_id(token)
    end

    def id_to_token(id : UInt32) : String?
      @model.id_to_token(id)
    end

    def vocab : Hash(String, UInt32)
      @model.vocab
    end

    def vocab_size : UInt32
      @model.vocab_size
    end

    def save(folder : String, name : String? = nil) : Array(String)
      @model.save(folder, name)
    end

    def trainer
      raise "Use TrainerWrapper via get_trainer"
    end

    def ==(other : self) : Bool
      @model == other.model
    end

    def to_json : String
      String.build do |io|
        JSON.build(io) do |json|
          case m = @model
          when Models::BPE::BPE
            json.raw(m.to_json)
          when Models::WordPiece
            json.raw(m.to_json)
          when Models::WordLevel
            json.raw(m.to_json)
          when Models::Unigram::Unigram
            json.raw(m.to_json)
          end
        end
      end
    end

    def self.from_json(json_str : String) : self
      data = JSON.parse(json_str)
      raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
      obj = data.as_h

      # Tagged path
      if type = obj["type"]?.try(&.as_s?)
        return from_tagged(type, json_str)
      end

      # Untagged path - try each model in order
      # WordPiece before WordLevel for retrocompatibility (WordPiece is subset)
      from_untagged(json_str)
    end

    def self.from_json(data : JSON::Any) : self
      raise JSON::ParseException.new("Expected object", 0, 0) unless data.as_h?
      obj = data.as_h

      if type = obj["type"]?.try(&.as_s?)
        return from_tagged(type, obj)
      end

      from_untagged(data)
    end

    private def self.from_tagged(type : String, json_str : String) : self
      begin
        case type
        when "BPE"
          return new(Models::BPE::BPE.from_json(json_str))
        when "WordPiece"
          return new(Models::WordPiece.from_json(json_str))
        when "WordLevel"
          return new(Models::WordLevel.from_json(json_str))
        when "Unigram"
          return new(Models::Unigram::Unigram.from_json(json_str))
        end
      rescue ex : JSON::ParseException
        raise ex
      rescue ex
        raise JSON::ParseException.new(ex.message || "Invalid model JSON", 0, 0)
      end
      raise JSON::ParseException.new("Unknown model type: #{type}", 0, 0)
    end

    private def self.from_tagged(type : String, obj : Hash(String, JSON::Any)) : self
      begin
        case type
        when "BPE"
          return new(Models::BPE::BPE.from_json(obj))
        when "WordPiece"
          return new(Models::WordPiece.from_json(JSON::Any.new(obj)))
        when "WordLevel"
          return new(Models::WordLevel.from_json(JSON::Any.new(obj)))
        when "Unigram"
          return new(Models::Unigram::Unigram.from_json(JSON::Any.new(obj)))
        end
      rescue ex : JSON::ParseException
        raise ex
      rescue ex
        raise JSON::ParseException.new(ex.message || "Invalid model JSON", 0, 0)
      end
      raise JSON::ParseException.new("Unknown model type: #{type}", 0, 0)
    end

    private def self.from_untagged(json_str : String) : self
      # BPE first, then WordPiece, then WordLevel (WordLevel is a subset of WordPiece fields)
      begin
        return new(Models::BPE::BPE.from_json(json_str))
      rescue
      end

      begin
        return new(Models::WordPiece.from_json(json_str))
      rescue
      end

      begin
        return new(Models::WordLevel.from_json(json_str))
      rescue
      end

      begin
        return new(Models::Unigram::Unigram.from_json(json_str))
      rescue
      end

      raise JSON::ParseException.new("data did not match any Model variant", 0, 0)
    end

    private def self.from_untagged(data : JSON::Any) : self
      begin
        return new(Models::BPE::BPE.from_json(data))
      rescue
      end

      begin
        return new(Models::WordPiece.from_json(data))
      rescue
      end

      begin
        return new(Models::WordLevel.from_json(data))
      rescue
      end

      begin
        return new(Models::Unigram::Unigram.from_json(data))
      rescue
      end

      raise JSON::ParseException.new("data did not match any Model variant", 0, 0)
    end
  end

  class TrainerWrapper
    alias Wrapped = Models::BPE::BpeTrainer |
                    Models::WordPieceTrainer |
                    Models::WordLevelTrainer |
                    Models::Unigram::UnigramTrainer

    getter trainer : Wrapped

    def initialize(@trainer : Wrapped)
    end

    def should_show_progress? : Bool
      @trainer.should_show_progress?
    end

    def train(model : ModelWrapper) : Array(AddedToken)
      case t = @trainer
      when Models::BPE::BpeTrainer
        case m = model.model
        when Models::BPE::BPE
          t.do_train(t.words, m)
        else
          raise "BpeTrainer can only train a BPE"
        end
      when Models::WordPieceTrainer
        case m = model.model
        when Models::WordPiece
          t.train(m)
        else
          raise "WordPieceTrainer can only train a WordPiece"
        end
      when Models::WordLevelTrainer
        case m = model.model
        when Models::WordLevel
          t.train(m)
        else
          raise "WordLevelTrainer can only train a WordLevel"
        end
      when Models::Unigram::UnigramTrainer
        case m = model.model
        when Models::Unigram::Unigram
          t.train(m)
        else
          raise "UnigramTrainer can only train a Unigram"
        end
      else
        raise "Unknown trainer type"
      end
    end

    def ==(other : self) : Bool
      @trainer == other.trainer
    end

    def to_json : String
      String.build do |io|
        JSON.build(io) do |json|
          case t = @trainer
          when Models::BPE::BpeTrainer
            json.object do
              json.field "type", "BpeTrainer"
              json.field "min_frequency", t.min_frequency
              json.field "vocab_size", t.vocab_size
              json.field "show_progress", t.show_progress
              json.field "special_tokens" do
                json.array do
                  t.special_tokens.each { |tok| tok.to_json(json) }
                end
              end
            end
          when Models::WordPieceTrainer
            json.object do
              json.field "type", "WordPieceTrainer"
              json.field "vocab_size", t.vocab_size
            end
          when Models::WordLevelTrainer
            json.object do
              json.field "type", "WordLevelTrainer"
              json.field "vocab_size", t.vocab_size
            end
          when Models::Unigram::UnigramTrainer
            json.object do
              json.field "type", "UnigramTrainer"
              json.field "vocab_size", t.vocab_size
            end
          end
        end
      end
    end
  end
end
