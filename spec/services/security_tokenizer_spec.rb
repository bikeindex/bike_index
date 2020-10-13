require "rails_helper"

RSpec.describe SecurityTokenizer do
  describe "new_token" do
    let(:token) { SecurityTokenizer.new_token }
    it "is long" do
      expect(token.length).to be > 20
      expect(SecurityTokenizer.token_time(token)).to be_within(1).of Time.current
    end
  end

  describe "short_token" do
    let(:token) { SecurityTokenizer.new_short_token }
    it "is short" do
      expect(token.length).to be < 72
    end
  end
end
