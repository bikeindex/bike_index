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
        expect(EmailNormalizer.normalize()).to be_nil
      end
    end
  end
end
