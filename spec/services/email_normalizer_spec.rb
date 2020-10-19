require "rails_helper"

RSpec.describe EmailNormalizer do
  describe "normalize" do
    context "spaces and capitals" do
      it "normalizes them" do
        expect(EmailNormalizer.normalize(" awesome@stuff.COM \t")).to eq "awesome@stuff.com"
      end
    end
    context "nil" do
      it "doesn't break on nil" do
        expect(EmailNormalizer.normalize).to be_nil
      end
    end
  end

  describe "obfuscate" do
    it "removes some stuff" do
      expect(EmailNormalizer.obfuscate("seth@example.com")).to eq "se**@e********om"
    end
    it "doesn't remove things if there aren't enough characters" do
      expect(EmailNormalizer.obfuscate("s@e.com")).to eq "s@e**om" # good enough
    end
    it "removes subdomains" do
      expect(EmailNormalizer.obfuscate("s*th@example.stuff.com")).to eq "s***@e**************om"
    end
  end
end
