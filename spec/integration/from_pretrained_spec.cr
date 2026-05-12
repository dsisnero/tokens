require "../spec_helper"

# These tests require network access to HuggingFace Hub.
# Skip unless FROM_PRETRAINED=1 is set.
private def network_available? : Bool
  ENV["FROM_PRETRAINED"]? == "1"
end

describe "from_pretrained" do
  it "test_from_pretrained" do
    next unless network_available?

    tokenizer = Tokens::TokenizerImpl.from_pretrained("bert-base-cased")
    encoding = tokenizer.encode("Hey there dear friend!", false)
    encoding.tokens.should eq(["Hey", "there", "dear", "friend", "!"])
  end

  it "test_from_pretrained_revision" do
    next unless network_available?

    tokenizer = Tokens::TokenizerImpl.from_pretrained("anthony/tokenizers-test")
    encoding = tokenizer.encode("Hey there dear friend!", false)
    encoding.tokens.should eq(["hey", "there", "dear", "friend", "!"])

    tokenizer = Tokens::TokenizerImpl.from_pretrained(
      "anthony/tokenizers-test",
      Tokens::FromPretrainedParameters.new(revision: "gpt-2"),
    )
    encoding = tokenizer.encode("Hey there dear friend!", false)
    encoding.tokens.should eq(["Hey", "Ġthere", "Ġdear", "Ġfriend", "!"])
  end

  it "test_from_pretrained_invalid_model" do
    expect_raises(Exception, /invalid characters/) do
      Tokens.from_pretrained("docs?")
    end
  end

  it "test_from_pretrained_invalid_revision" do
    expect_raises(Exception, /invalid characters/) do
      Tokens.from_pretrained("bert-base-cased", Tokens::FromPretrainedParameters.new(revision: "gpt?"))
    end
  end
end
