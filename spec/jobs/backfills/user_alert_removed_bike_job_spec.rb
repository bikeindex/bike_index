require "rails_helper"

RSpec.describe Backfills::UserAlertRemovedBikeJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let!(:user_alert_deleted) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
  let!(:user_alert_kept) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
  let!(:user_alert_recovered) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
  let(:bike_registered) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
  let(:b_param) { FactoryBot.create(:b_param_unfinished_registration, creator: user, created_bike_id: bike_registered.id) }
  let!(:user_alert_registration) { FactoryBot.create(:user_alert, user:, kind: "unfinished_registration", alertable: b_param) }

  it "resolves the alerts about bikes that are gone or recovered" do
    user_alert_recovered.bike.current_stolen_record.add_recovery_information
    FactoryBot.create(:education_course_acknowledgment_pending, b_param:, bike: bike_registered)
    # What a delete left behind, before deleting refreshed alerts
    user_alert_deleted.bike.update_column(:deleted_at, Time.current)
    bike_registered.update_column(:deleted_at, Time.current)
    UserAlert.refresh_alert_slugs(user)
    expect(user.reload.alert_slugs).to eq %w[stolen_bike_without_location unfinished_registration]

    described_class.new.perform

    expect(user_alert_deleted.reload.resolved?).to be_truthy
    expect(user_alert_registration.reload.resolved?).to be_truthy
    expect(user_alert_recovered.reload.resolved?).to be_truthy
    expect(user_alert_kept.reload.active?).to be_truthy
    expect(user.reload.alert_slugs).to eq %w[stolen_bike_without_location]
  end
end
