require "rails_helper"

RSpec.describe UserServices::PasswordlessCreator do
  describe "find_or_create" do
    let(:email) { "newregistrant@example.com" }

    it "creates a confirmed user nobody has the password to" do
      user, signed_up = described_class.find_or_create(email)
      expect(user).to have_attributes(email:, confirmed: true, passwordless_user: true)
      expect(user.authenticate("")).to be_falsey
      expect(signed_up).to be_truthy

      # Called again for the same address, it finds rather than duplicates
      expect(described_class.find_or_create(email)).to eq([user, false])
      expect(described_class.find_or_create(" NewRegistrant@example.com ")).to eq([user, false])
    end

    context "unconfirmed user with the email" do
      let!(:user) { FactoryBot.create(:user, email:) }

      it "returns them, leaving them unconfirmed" do
        expect(described_class.find_or_create(email)).to eq([user, false])
        expect(user.reload.confirmed).to be_falsey
      end
    end

    context "blank email" do
      it "is nil" do
        expect(described_class.find_or_create(" ")).to eq([nil, false])
      end
    end
  end
end
