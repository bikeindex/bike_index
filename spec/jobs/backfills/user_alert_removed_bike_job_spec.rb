require "rails_helper"

RSpec.describe Backfills::UserAlertRemovedBikeJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let!(:user_alert_deleted) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
  let!(:user_alert_kept) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
  let(:bike_registered) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
  let(:b_param) do
    FactoryBot.create(:b_param, creator: user, origin: "register_flow", created_bike_id: bike_registered.id,
      params: {bike: {manufacturer_id: 1, owner_email: user.email}})
  end
  let!(:user_alert_registration) { FactoryBot.create(:user_alert, user:, kind: "unfinished_registration", alertable: b_param) }

  it "resolves the alerts about bikes that are gone" do
    FactoryBot.create(:education_course_acknowledgment_pending, b_param:, bike: bike_registered)
    # The state deleting left behind, before deleting refreshed the alerts
    user_alert_deleted.bike.update_column(:deleted_at, Time.current)
    bike_registered.update_column(:deleted_at, Time.current)
    UserAlert.refresh_alert_slugs(user)
    expect(user.reload.alert_slugs).to eq %w[stolen_bike_without_location unfinished_registration]

    described_class.new.perform

    expect(user_alert_deleted.reload.resolved?).to be_truthy
    expect(user_alert_registration.reload.resolved?).to be_truthy
    expect(user_alert_kept.reload.active?).to be_truthy
    expect(user.reload.alert_slugs).to eq %w[stolen_bike_without_location]
  end
end
