require "rails_helper"

RSpec.describe CreateGraduatedNotificationWorker, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:graduated_notification_interval) { 1.year.to_i }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: graduated_notification_interval) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, created_at: Time.current - (3 * graduated_notification_interval)) }

    describe "enqueue notifications" do
      it "enqueues notifications" do
        expect(organization.deliver_graduated_notifications?).to be_truthy
        Sidekiq::Worker.clear_all
        expect {
          instance.perform
        }.to change(described_class.jobs, :count).by 1
        expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([organization.id, bike.id])
      end
      context "organization does not have graduated_notification_interval" do
        let(:graduated_notification_interval) { 0 }
        it "does not enqueue notifications" do
          expect(organization.graduated_notification_interval).to be_blank
          expect(organization.deliver_graduated_notifications?).to be_falsey
          Sidekiq::Worker.clear_all
          expect {
            instance.perform
          }.to_not change(described_class.jobs, :count)
        end
      end
    end

    describe "create notification" do
      it "creates notification only once" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect {
            instance.perform
            instance.perform
            instance.perform
            instance.perform
          }.to change(GraduatedNotification, :count).by 1
        end

        expect(ActionMailer::Base.deliveries.count).to eq 0
        graduated_notification = GraduatedNotification.last
        expect(graduated_notification.status).to eq "pending"
        expect(graduated_notification.in_pending_period?).to be_truthy
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.bike_id).to eq bike.id
        expect(graduated_notification.organization_id).to eq organization.id
      end
    end

    context "with existing graduated_notification" do
      let!(:graduated_notification_active) { FactoryBot.create(:graduated_notification_active, organization: organization) }

      let!(:graduated_notification_remaining_expired) do
        FactoryBot.create(:graduated_notification,
          :marked_remaining,
          organization: organization,
          bike: bike,
          marked_remaining_at: Time.current - (2 * graduated_notification_interval))
      end
      let!(:graduated_notification_remaining) do
        FactoryBot.create(:graduated_notification,
          :marked_remaining,
          organization: organization,
          marked_remaining_at: Time.current - graduated_notification_interval + 2.days)
      end

      it "enqueues and creates" do
        # Couple of tests to ensure we're making the factories right
        expect(graduated_notification_remaining_expired.created_at).to be < graduated_notification_remaining_expired.marked_remaining_at
        expect(graduated_notification_active.processed_at).to be < Time.current
        expect(graduated_notification_active.status).to eq("active")
        # Really, testing bike_ids_to_notify ensures we're enqueueing the right things, but - just to be sure
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to match_array([bike.id])
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(bike.graduated?(organization)).to be_falsey
        expect(bike.graduated_notifications(organization).pluck(:id)).to eq([graduated_notification_remaining_expired.id])
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect {
            instance.perform
            instance.perform
            instance.perform
          }.to change(GraduatedNotification, :count).by 1
        end
        graduated_notification = GraduatedNotification.last
        expect(graduated_notification.status).to eq "pending"
        expect(graduated_notification.in_pending_period?).to be_truthy
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.bike_id).to eq bike.id
        expect(graduated_notification.organization_id).to eq organization.id
      end
    end
  end
end
