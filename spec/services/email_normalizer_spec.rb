require 'spec_helper'

describe EmailNormalizer do

  describe :normalized do 
    it "normalizes with spaces and downcase" do 
      normalizer = EmailNormalizer.new(" awesome@stuff.COM \t")
      expect(normalizer.normalized).to eq('awesome@stuff.com')
    end

    it "doesn't break on nil" do 
      normalizer = EmailNormalizer.new
      expect(normalizer.normalized).to eq('')
    end
  end

end
