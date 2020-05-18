require "rails_helper"

RSpec.describe AfterUserChangeWorker, type: :job do
  let(:instance) { described_class.new }

  context "no user" do
    it "does not raise an error" do
      expect(instance.perform(238181813)).to be_falsey
    end
  end

  describe "stolen records missing locations" do
    let(:user) { FactoryBot.create(:user) }
    let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: ownership.bike, street: "         ") }
    let(:ownership_with_location) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
    let!(:stolen_record_with_location) { FactoryBot.create(:stolen_record, bike: ownership_with_location.bike, street: "some cool street") }
    let(:ownership_unclaimed) { FactoryBot.create(:ownership, creator: user) }
    let!(:stolen_record_unclaimed) { FactoryBot.create(:stolen_record, bike: ownership_unclaimed.bike) }
    it "lists the bikes with missing locations" do
      # Ensure we've got the current stolen records set
      stolen_record.bike.update_attributes(updated_at: Time.current)
      stolen_record_with_location.bike.update_attributes(updated_at: Time.current)
      stolen_record_unclaimed.bike.update_attributes(updated_at: Time.current)
      expect(stolen_record.bike.current_stolen_record).to eq stolen_record
      expect(stolen_record_with_location.bike.current_stolen_record).to eq stolen_record_with_location
      expect(stolen_record_unclaimed.bike.current_stolen_record).to eq stolen_record_unclaimed
      # Test that the missing location is there
      expect(stolen_record.without_location?).to be_truthy
      expect(stolen_record_with_location.without_location?).to be_falsey
      expect(stolen_record_unclaimed.without_location?).to be_truthy
      expect(stolen_record.bike.user).to eq user
      expect(stolen_record_with_location.bike.user).to eq user
      expect(stolen_record_unclaimed.bike.user).to be_blank
      # Unmemoize the stolen_bikes_without_locations
      user_id = user.id
      user = User.find(user_id)
      user.save
      expect(stolen_record.bike.stolen).to be_truthy
      expect(stolen_record_with_location.bike.stolen).to be_truthy
      expect(user.rough_approx_bikes.stolen.pluck(:id)).to match_array([stolen_record.bike_id, stolen_record_with_location.bike_id])
      expect(user.rough_stolen_bikes.select { |b| b.current_stolen_record.without_location? }.map(&:id)).to eq([stolen_record.bike_id])
      instance.perform(user.id)

      user.reload
      expect(user.general_alerts).to eq(["stolen_bikes_without_locations"])

      FactoryBot.create(:theft_alert, stolen_record: stolen_record)
      instance.perform(user.id)
      user.reload
      expect(user.general_alerts).to eq(%w[stolen_bikes_without_locations theft_alert_without_photo])

      membership = FactoryBot.create(:membership_claimed, user: user, role: "admin")
      instance.perform(user.id)
      user.reload
      expect(user.general_alerts).to eq(["theft_alert_without_photo"])

      membership.destroy
      user.update(superuser: true)
      instance.perform(user.id)
      user.reload
      expect(user.general_alerts).to eq([])
    end
  end
end
