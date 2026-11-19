require "rails_helper"

RSpec.describe PosRegistrationMatch, type: :model do
  describe "bike and pos_bike" do
    let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

    it "includes deleted and hidden registrations, preloaded too" do
      match.pos_bike.update!(marked_user_hidden: true)
      match.bike.destroy!
      expect(described_class.includes(:bike, :pos_bike).find(match.id)).to have_attributes(bike: match.bike, pos_bike: match.pos_bike)
    end
  end
end
