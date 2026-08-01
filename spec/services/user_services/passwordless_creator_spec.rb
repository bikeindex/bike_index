require "rails_helper"

RSpec.describe UserServices::PasswordlessCreator do
  describe "find_or_create" do
    let(:email) { "newregistrant@example.com" }

    it "creates a confirmed user nobody has the password to" do
      user = described_class.find_or_create(email)
      expect(user).to have_attributes(email:, confirmed: true)
      expect(user.authenticate("")).to be_falsey
      # Called again for the same address, it finds rather than duplicates
      expect(described_class.find_or_create(email)).to eq user
      expect(described_class.find_or_create(" NewRegistrant@example.com ")).to eq user
    end

    context "unconfirmed user with the email" do
      let!(:user) { FactoryBot.create(:user, email:) }

      it "returns them, leaving them unconfirmed" do
        expect(described_class.find_or_create(email)).to eq user
        expect(user.reload.confirmed).to be_falsey
      end
    end

    context "blank email" do
      it "is nil" do
        expect(described_class.find_or_create(" ")).to be_nil
      end
    end
  end
end
