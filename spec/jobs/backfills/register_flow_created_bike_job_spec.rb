require "rails_helper"

RSpec.describe Backfills::RegisterFlowCreatedBikeJob, type: :job do
  describe "perform" do
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:bike_created_at) { Time.current }
    let!(:b_param) { FactoryBot.create(:b_param_unfinished_registration, creator: user, manufacturer:) }
    let!(:other_type) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user,
        params: {bike: {manufacturer_id: manufacturer.id, cycle_type: "tandem", owner_email: user.email}})
    end
    let!(:other_serial) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user,
        params: {bike: {manufacturer_id: manufacturer.id, cycle_type: "cargo", owner_email: user.email,
                        serial_number: "something else"}})
    end
    let!(:bike) do
      FactoryBot.create(:bike, manufacturer:, cycle_type: "cargo", owner_email: user.email, created_at: bike_created_at)
    end

    it "attaches the bike registered since to the registrations it matches" do
      expect(user.reload.alert_slugs).to eq ["unfinished_registration"]

      Sidekiq::Testing.inline! { described_class.perform_async }

      expect(b_param.reload.created_bike_id).to eq bike.id
      expect(other_type.reload.with_bike?).to be_falsey
      expect(other_serial.reload.with_bike?).to be_falsey
      expect(user.user_alerts.active.unfinished_registration.map(&:alertable)).to match_array [other_type, other_serial]
    end

    context "with the bike registered before the registration started" do
      let(:bike_created_at) { Time.current - 1.day }

      it "leaves it unfinished" do
        Sidekiq::Testing.inline! { described_class.perform_async }

        expect(b_param.reload.with_bike?).to be_falsey
      end
    end
  end
end
