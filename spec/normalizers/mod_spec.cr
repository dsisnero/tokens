require "../spec_helper"

module Tokens
  describe NormalizerWrapper do
    it "deserializes legacy no-type normalizers when unambiguous" do
      strip = NormalizerWrapper.from_json(%({"strip_left":false,"strip_right":true}))
      strip.should be_a(NormalizerWrapper)
      strip.normalizer.should be_a(Tokens::Normalizers::Strip)

      prepend = NormalizerWrapper.from_json(%({"prepend":"a"}))
      prepend.normalizer.should be_a(Tokens::Normalizers::Prepend)
    end

    it "rejects ambiguous legacy no-type objects" do
      expect_raises(Exception, "data did not match any variant of untagged enum NormalizerUntagged") do
        NormalizerWrapper.from_json(%({"trim_offsets":true,"add_prefix_space":true}))
      end
    end

    it "deserializes tagged sequences and rejects invalid sequence payloads" do
      sequence = NormalizerWrapper.from_json(%({"type":"Sequence","normalizers":[]}))
      sequence.normalizer.should be_a(Tokens::Normalizers::Sequence)

      expect_raises(Exception, "data did not match any variant of untagged enum NormalizerUntagged") do
        NormalizerWrapper.from_json(%({"type":"Sequence","normalizers":[{}]}))
      end

      expect_raises(Exception, "data did not match any variant of untagged enum NormalizerUntagged") do
        NormalizerWrapper.from_json(%({"replacement":"▁","prepend_scheme":"always"}))
      end

      expect_raises(Exception, "missing field `normalizers`") do
        NormalizerWrapper.from_json(%({"type":"Sequence","prepend_scheme":"always"}))
      end
    end
  end
end
