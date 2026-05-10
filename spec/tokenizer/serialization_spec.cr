require "../spec_helper"

describe Tokens::TokenizerImpl do
  it "serializes and deserializes round-trip" do
    tok_json = %({"version":"1.0","truncation":null,"padding":null,"added_tokens":[{"id":0,"content":"[SPECIAL_0]","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true},{"id":1,"content":"[SPECIAL_1]","single_word":false,"lstrip":false,"rstrip":false,"normalized":true,"special":false},{"id":2,"content":"[SPECIAL_2]","single_word":false,"lstrip":false,"rstrip":false,"normalized":false,"special":true}],"normalizer":null,"pre_tokenizer":null,"post_processor":null,"decoder":null,"model":{"type":"BPE","dropout":null,"unk_token":null,"continuing_subword_prefix":null,"end_of_word_suffix":null,"fuse_unk":false,"byte_fallback":false,"ignore_merges":false,"vocab":{},"merges":[]}})

    tokenizer = Tokens::TokenizerImpl.from_json(tok_json)
    tokenizer.should be_a(Tokens::TokenizerImpl)

    # Round-trip: serialize and deserialize again
    serialized = tokenizer.to_json
    restored = Tokens::TokenizerImpl.from_json(serialized)
    restored.should be_a(Tokens::TokenizerImpl)

    # Verify added tokens survived round-trip
    restored.get_added_vocabulary.len.should eq(3)
  end

  it "rejects unknown versions" do
    invalid = %({"version":"0.0","model":{"type":"BPE","vocab":{},"merges":[]},"added_tokens":[]})

    expect_raises(Exception, /Unknown tokenizer version/) do
      Tokens::TokenizerImpl.from_json(invalid)
    end
  end

  it "rejects missing model" do
    invalid = %({"version":"1.0","added_tokens":[]})

    expect_raises(Exception, /Missing model/) do
      Tokens::TokenizerImpl.from_json(invalid)
    end
  end
end
