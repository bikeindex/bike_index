require 'spec_helper'

describe EmailNormalizer do
  describe 'normalize' do
    context 'spaces and capitals' do
      it 'normalizes them' do
        expect(EmailNormalizer.normalize(" awesome@stuff.COM \t")).to eq 'awesome@stuff.com'
      end
    end
    context 'nil' do
      it "doesn't break on nil" do
        normalizer = EmailNormalizer.normalize().to eq ''
        expect(normalizer.normalized).to eq('')
      end
    end
  end
end
