# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::OrgSearch, type: :service do
  describe ".email_and_name" do
    let!(:bike1) { FactoryBot.create(:bike, owner_email: "something@stuff.edu") }
    let(:user) { FactoryBot.create(:user_confirmed, name: "George Jones", email: "something2@stuff.edu") }
    let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, owner_email: user.email, user: user) }
    let!(:bike3) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: {user_name: "Sally Jones"}, owner_email: "something@stuff.com") }
    it "finds the things" do
      expect(bike2.reload.owner_name).to eq "George Jones"
      expect(bike3.reload.owner_name).to eq "Sally Jones"
      expect(described_class.email_and_name(Bike.all, "something").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, " stuff ").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, "\nstuff.EDU  ").pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(described_class.email_and_name(Bike.all, "jones").pluck(:id)).to match_array([bike2.id, bike3.id])
      expect(described_class.email_and_name(Bike.all, "  sally").pluck(:id)).to match_array([bike3.id])
      expect(Bike.claimed.pluck(:id)).to eq([bike2.id])
    end
  end
end
