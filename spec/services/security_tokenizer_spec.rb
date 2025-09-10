require "rails_helper"

RSpec.describe SecurityTokenizer do
  describe "new_token" do
    let(:token) { SecurityTokenizer.new_token }
    it "is long" do
      expect(token.length).to be > 50
      expect(token).to match("-")
      expect(SecurityTokenizer.token_time(token)).to be_within(2).of Time.current
    end
  end

  describe "new_password_token" do
    let(:token) { SecurityTokenizer.new_password_token }
    it "is slightly shorter" do
      expect(token.length).to be < 72 # Max password length
      expect(token).to match("-")
      expect(SecurityTokenizer.token_time(token)).to be > (Time.current - 2)
    end
  end

  describe "new_short_token" do
    let(:token) { SecurityTokenizer.new_short_token }
    it "is short" do
      expect(token.length).to_not match("-")
      expect(SecurityTokenizer.token_time(token)).to eq Time.at(SecurityTokenizer::EARLIEST_TOKEN_TIME)
      expect(token.length).to be < 30
    end
  end
end
