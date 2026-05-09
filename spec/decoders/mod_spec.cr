require "../spec_helper"

describe Tokens::DecoderWrapper do
  it "serializes and deserializes sequence decoders" do
    old_json = %({"type":"Sequence","decoders":[{"type":"ByteFallback"},{"type":"Metaspace","replacement":"▁","add_prefix_space":true,"prepend_scheme":"always"}]})
    old_decoder = Tokens::DecoderWrapper.from_json(old_json)
    old_decoder.to_json.should eq(%({"type":"Sequence","decoders":[{"type":"ByteFallback"},{"type":"Metaspace","replacement":"▁","prepend_scheme":"always","split":true}]}))

    json = %({"type":"Sequence","decoders":[{"type":"ByteFallback"},{"type":"Metaspace","replacement":"▁","prepend_scheme":"always","split":true}]})
    decoder = Tokens::DecoderWrapper.from_json(json)
    decoder.to_json.should eq(json)
  end

  it "serializes unit decoders inside a sequence" do
    json = %({"type":"Sequence","decoders":[{"type":"Fuse"},{"type":"Metaspace","replacement":"▁","prepend_scheme":"always","split":true}]})
    decoder = Tokens::DecoderWrapper.from_json(json)

    decoder.to_json.should eq(json)
  end

  it "matches upstream deserialization failures" do
    expect_raises(Exception, "data did not match any variant of untagged enum DecoderUntagged") do
      Tokens::DecoderWrapper.from_json(%({"type":"Sequence","decoders":[{},{"type":"Metaspace","replacement":"▁","prepend_scheme":"always"}]}))
    end

    expect_raises(Exception, "data did not match any variant of untagged enum DecoderUntagged") do
      Tokens::DecoderWrapper.from_json(%({"replacement":"▁","prepend_scheme":"always"}))
    end

    expect_raises(Exception, "missing field `decoders`") do
      Tokens::DecoderWrapper.from_json(%({"type":"Sequence","prepend_scheme":"always"}))
    end
  end
end
