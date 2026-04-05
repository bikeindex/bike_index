require "rails_helper"

RSpec.describe UserNameValidator do
  describe ".valid?" do
    it "is false for reserved route names" do
      expect(described_class.valid?("admin")).to be false
      expect(described_class.valid?("bikes")).to be false
      expect(described_class.valid?("api")).to be false
      expect(described_class.valid?("users")).to be false
      expect(described_class.valid?("organizations")).to be false
      expect(described_class.valid?("logout")).to be false
      expect(described_class.valid?("my_account")).to be false
    end

    it "is false for plural/singular variations of reserved names" do
      expect(described_class.valid?("admins")).to be false
      expect(described_class.valid?("bike")).to be false
      expect(described_class.valid?("organization")).to be false
    end

    it "is false for very short names" do
      expect(described_class.valid?("a")).to be false
    end

    it "is true for normal usernames" do
      expect(described_class.valid?("coolbiker")).to be true
      expect(described_class.valid?("jane_doe")).to be true
      expect(described_class.valid?("bikelover42")).to be true
    end
  end

  describe "User model validation" do
    let(:user) { FactoryBot.build(:user, username:) }

    context "when username is a reserved name" do
      let(:username) { "admin" }

      it "is invalid" do
        expect(user).to_not be_valid
        expect(user.errors[:username]).to include("is reserved")
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
