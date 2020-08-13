require "rails_helper"

RSpec.describe ProcessGraduatedNotificationWorker, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 55.minutes
  end

  describe "perform" do
    let(:graduated_notification_interval) { 2.years.to_i }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: graduated_notification_interval) }
    let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, owner_email: "notify@bike.com", created_at: Time.current - (2 * graduated_notification_interval)) }
    let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, owner_email: "notify@bike.com", created_at: Time.current - 1.week) }
    let!(:graduated_notification_active) { FactoryBot.create(:graduated_notification_active, organization: organization) }
    let!(:graduated_notification_processable) { FactoryBot.create(:graduated_notification, organization: organization, created_at: Time.current - GraduatedNotification::PENDING_PERIOD - 55.minutes) }
    let!(:graduated_notification_primary) { FactoryBot.create(:graduated_notification, organization: organization, bike: bike1, created_at: Time.current - 30.minutes) }

    it "enqueues the expected notifications and only sends one email" do
      graduated_notification_primary.reload
      expect(graduated_notification_primary.primary_notification?).to be_truthy
      expect(graduated_notification_primary.associated_notifications.pluck(:id)).to eq([])
      ActionMailer::Base.deliveries = []
      Sidekiq::Testing.inline! do
        expect {
          instance.perform
          instance.perform
          instance.perform
          instance.perform
        }.to change(GraduatedNotification, :count).by 1
      end
      expect(ActionMailer::Base.deliveries.count).to eq 1
      # Also, manually test that enqueuing the processable one again doesn't send an email
      instance.perform(graduated_notification_processable.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1

      graduated_notification_processable.reload
      expect(graduated_notification_processable.processed?).to be_truthy
      expect(graduated_notification_processable.email_success?).to be_truthy

      graduated_notification_secondary = GraduatedNotification.last
      expect(graduated_notification_secondary.primary_notification_id).to eq(graduated_notification_primary.id)
      expect(graduated_notification_secondary.primary_bike_id).to eq(bike1.id)
      expect(graduated_notification_secondary.bike_id).to eq(bike2.id)
      expect(graduated_notification_secondary.organization_id).to eq(organization.id)
      expect(graduated_notification_secondary.status).to eq "pending"
      expect(graduated_notification_secondary.processed?).to be_falsey
      expect(graduated_notification_secondary.send_email?).to be_falsey

      graduated_notification_primary.reload
      expect(graduated_notification_primary.status).to eq "pending"
      expect(graduated_notification_primary.processed?).to be_falsey
      expect(graduated_notification_primary.email_success?).to be_falsey
      expect(graduated_notification_primary.send_email?).to be_truthy
      expect(graduated_notification_primary.associated_notifications.pluck(:id)).to eq([graduated_notification_secondary.id])
    end
  end
end
