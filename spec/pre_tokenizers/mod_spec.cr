require "../spec_helper"

describe Tokens::PreTokenizerWrapper do
  it "deserializes tagged sequence and metaspace defaults" do
    wrapper = Tokens::PreTokenizerWrapper.from_json(%({"type":"Sequence","pretokenizers":[{"type":"WhitespaceSplit"},{"type":"Metaspace","replacement":"▁","add_prefix_space":true}]}))

    wrapper.should eq(Tokens::PreTokenizerWrapper.from(
      Tokens::PreTokenizers::Sequence.new([
        Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::WhitespaceSplit.new),
        Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)),
      ])
    ))

    Tokens::PreTokenizerWrapper.from_json(%({"type":"Metaspace","replacement":"▁","add_prefix_space":true}))
      .should eq(Tokens::PreTokenizerWrapper.from(
        Tokens::PreTokenizers::Metaspace.new('▁', Tokens::PreTokenizers::PrependScheme::Always, true)
      ))
  end

  it "deserializes whitespace split" do
    Tokens::PreTokenizerWrapper.from_json(%({"type":"WhitespaceSplit"}))
      .should eq(Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::WhitespaceSplit.new))
  end

  it "deserializes unicode scripts" do
    Tokens::PreTokenizerWrapper.from_json(%({"type":"UnicodeScripts"}))
      .should eq(Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::UnicodeScripts.new))
  end

  it "matches upstream no-type and missing-field failures" do
    expect_raises(Exception, "data did not match any variant of untagged enum PreTokenizerUntagged") do
      Tokens::PreTokenizerWrapper.from_json(%({"replacement":"▁","add_prefix_space":true,"prepend_scheme":"always"}}))
    end

    Tokens::PreTokenizerWrapper.from_json(%({"type":"Metaspace","replacement":"▁"}))
      .should eq(Tokens::PreTokenizerWrapper.from(Tokens::PreTokenizers::Metaspace.default))

    expect_raises(Exception, "missing field `replacement`") do
      Tokens::PreTokenizerWrapper.from_json(%({"type":"Metaspace","add_prefix_space":true}))
    end

    expect_raises(Exception, "data did not match any variant of untagged enum PreTokenizerUntagged") do
      Tokens::PreTokenizerWrapper.from_json(%({"behavior":"default_split"}))
    end
  end
end
