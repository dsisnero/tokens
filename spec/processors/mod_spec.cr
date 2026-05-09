require "../spec_helper"

describe Tokens::PostProcessorWrapper do
  it "deserializes Bert and Roberta correctly" do
    roberta = Tokens::PostProcessorWrapper.from(Tokens::PostProcessors::RobertaProcessing.default)
    roberta_r = %({"type":"RobertaProcessing","sep":["</s>",2],"cls":["<s>",0],"trim_offsets":true,"add_prefix_space":true})
    roberta.to_json.should eq(roberta_r)
    Tokens::PostProcessorWrapper.from_json(roberta_r).should eq(roberta)

    bert = Tokens::PostProcessorWrapper.from(Tokens::PostProcessors::BertProcessing.default)
    bert_r = %({"type":"BertProcessing","sep":["[SEP]",102],"cls":["[CLS]",101]})
    bert.to_json.should eq(bert_r)
    Tokens::PostProcessorWrapper.from_json(bert_r).should eq(bert)
  end

  it "post_processor_deserialization_no_type" do
    json = %({"add_prefix_space": true, "trim_offsets": false, "use_regex": false})
    expect_raises(Exception, /data did not match any variant of untagged enum/) do
      Tokens::PostProcessorWrapper.from_json(json)
    end

    json = %({"sep":["[SEP]",102],"cls":["[CLS]",101]})
    wrapper = Tokens::PostProcessorWrapper.from_json(json)
    wrapper.processor.should be_a(Tokens::PostProcessors::BertProcessing)

    json = %({"sep":["</s>",2], "cls":["<s>",0], "trim_offsets":true, "add_prefix_space":true})
    wrapper = Tokens::PostProcessorWrapper.from_json(json)
    wrapper.processor.should be_a(Tokens::PostProcessors::RobertaProcessing)

    json = %({"type":"RobertaProcessing", "sep":["</s>",2]})
    expect_raises(Exception, /data did not match any variant of untagged enum/) do
      Tokens::PostProcessorWrapper.from_json(json)
    end
  end
end
