require "rails_helper"

RSpec.describe UserNameValidator do
  describe ".valid?" do
    it "is false for user collection route names" do
      expect(described_class.valid?("new")).to be false
      expect(described_class.valid?("confirm")).to be false
      expect(described_class.valid?("please_confirm_email")).to be false
      expect(described_class.valid?("request_password_reset_form")).to be false
      expect(described_class.valid?("send_password_reset_email")).to be false
    end

    it "is false for very short names" do
      expect(described_class.valid?("a")).to be false
    end

    it "is false for blank" do
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?("")).to be false
    end

    it "is false for bad words" do
      expect(described_class.valid?("fuck")).to be false
      expect(described_class.valid?("shit")).to be false
    end

    it "is true for normal usernames" do
      expect(described_class.valid?("coolbiker")).to be true
      expect(described_class.valid?("jane_doe")).to be true
      expect(described_class.valid?("bikelover42")).to be true
    end

    it "is true for names that are only reserved for organizations" do
      expect(described_class.valid?("admin")).to be true
      expect(described_class.valid?("bikes")).to be true
      expect(described_class.valid?("api")).to be true
    end
  end

  describe "User model validation" do
    let(:user) { FactoryBot.build(:user, username:) }

    context "when username is a reserved name" do
      let(:username) { "confirm" }

      it "is invalid" do
        expect(user).to_not be_valid
        expect(user.errors[:username]).to include("is reserved")
      end
    end

    context "when username is nil" do
      let(:username) { nil }

      it "is valid" do
        expect(user).to be_valid
      end
    end

    context "when username is valid" do
      let(:username) { "normaluser" }

      it "is valid" do
        expect(user).to be_valid
      end
    end
  end
end
