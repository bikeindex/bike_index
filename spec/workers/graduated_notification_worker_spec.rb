require "rails_helper"

RSpec.describe GraduatedNotificationWorker, type: :lib do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:organization1) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 12.days.to_i) }
    let(:organization2) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["graduated_notifications"]) }
    let!(:bike1) { FactoryBot.create(:bike_organized, organization: organization1, created_at: Time.current - 1.year) }
    let!(:bike2) { FactoryBot.create(:bike_organized, organization: organization2, created_at: Time.current - 1.year) }
    it "schedules all the workers" do
      expect(described_class.organizations.pluck(:id)).to eq([organization1.id])
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      expect do
        described_class.new.perform
      end.to change(described_class.jobs, :count).by(1)
      expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([organization1.id, bike1.id])

      # And then it creates the notification
      expect do
        described_class.drain
      end.to change(GraduatedNotification).by 1
      graduated_notification = GraduatedNotification.last
      expect(graduated_notification.delivery_status).to eq "email_success"
      expect(graduated_notification.status).to eq "delivered"
      expect(graduated_notification.active?).to be_truthy
      expect(graduated_notification.main_notification?).to be_truthy

      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    end
  end

  # describe "bikes_to_notify" do
  #   let(:user) { FactoryBot.create(:user) }
  #   let!(:bike1) do
  #     FactoryBot.create(:bike_organized,
  #                       :with_ownership_claimed,
  #                       user: user,
  #                       organization: organization,
  #                       created_at: Time.current - 13.days)
  #   end
  #   let!(:bike1) do
  #     FactoryBot.create(:bike_organized,
  #                       :with_ownership_claimed,
  #                       user: user,
  #                       organization: organization,
  #                       created_at: Time.current - 16.days)
  #   end
  #   it "creates for both bikes" do
  #     expect(GraduatedNotification.bikes_to_notify(organization).pluck(:id)).to eq([bike1.id])
  #     graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
  #     expect(graduated_notification1.main_notification?).to be_truthy
  #     expect(graduated_notification1.send_email?).to be_truthy
  #     organization.update(graduated_notification_interval_days: 7)
  #     expect(GraduatedNotification.bikes_to_notify(organization).pluck(:id)).to eq([bike2.id])
  #     graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
  #     expect(graduated_notification2.main_notification?).to be_falsey
  #     expect(graduated_notification2.primary_notification).to eq(graduated_notification1)
  #     expect(graduated_notification2.send_email?).to be_falsey
  #   end
  # end
end
