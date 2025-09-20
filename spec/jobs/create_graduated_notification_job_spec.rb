require "rails_helper"

RSpec.describe CreateGraduatedNotificationJob, type: :lib do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let(:graduated_notification_interval) { 1.year.to_i }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: graduated_notification_interval) }
    let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, created_at: Time.current - (3 * graduated_notification_interval)) }

    describe "enqueue notifications" do
      it "enqueues notifications" do
        expect(organization.deliver_graduated_notifications?).to be_truthy
        Sidekiq::Job.clear_all
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
          Sidekiq::Job.clear_all
          expect {
            instance.perform
          }.to_not change(described_class.jobs, :count)
        end
      end
      context "organization member bike" do
        let(:user) { FactoryBot.create(:organization_user, organization: organization) }
        let!(:ownership) { FactoryBot.create(:ownership_claimed, user: user, creator: user, bike: bike, organization: organization) }
        it "does not enqueue" do
          expect(bike.reload.current_ownership&.id).to eq ownership.id
          expect(bike.ownerships.count).to eq 2
          expect(bike.ownerships.current.count).to eq 1
          expect(organization.reload.bikes.pluck(:id)).to eq([bike.id])
          expect(organization.bikes_member.pluck(:id)).to eq([bike.id])
          expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([])
          expect(organization.deliver_graduated_notifications?).to be_truthy
          Sidekiq::Job.clear_all
          expect {
            instance.perform
          }.to change(described_class.jobs, :count).by 0
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
      let!(:graduated_notification_bike_graduated) { FactoryBot.create(:graduated_notification_bike_graduated, organization: organization) }

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
        expect(graduated_notification_remaining_expired.most_recent?).to be_truthy
        expect(graduated_notification_remaining_expired.expired?).to be_truthy
        expect(graduated_notification_bike_graduated.processed_at).to be < Time.current
        expect(graduated_notification_bike_graduated.status).to eq("bike_graduated")
        # Really, testing bike_ids_to_notify ensures we're enqueueing the right things, but - just to be sure
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to match_array([bike.id])
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(bike.graduated?(organization)).to be_falsey
        expect(bike.organization_graduated_notifications(organization).pluck(:id)).to eq([graduated_notification_remaining_expired.id])
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect {
            instance.perform
            instance.perform
            instance.perform
          }.to change(GraduatedNotification, :count).by 1
        end
        expect(graduated_notification_remaining_expired.reload.most_recent?).to be_falsey
        graduated_notification = GraduatedNotification.last
        expect(graduated_notification.primary_notification?).to be_truthy
        expect(graduated_notification.associated_notifications.pluck(:id)).to eq([])
        expect(graduated_notification.send(:existing_sent_notification)&.id).to be_blank
        expect(graduated_notification.status).to eq "pending"
        expect(graduated_notification.in_pending_period?).to be_truthy
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.bike_id).to eq bike.id
        expect(graduated_notification.organization_id).to eq organization.id
        expect(graduated_notification.most_recent?).to be_truthy
      end
    end

    context "other existing graduated_notifications" do
      let!(:graduated_notification_remaining_expired) do
        FactoryBot.create(:graduated_notification,
          :marked_remaining,
          organization: organization,
          bike: bike,
          created_at: Time.current - (2 * graduated_notification_interval),
          marked_remaining_at: Time.current - (2 * graduated_notification_interval))
      end

      let(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, created_at: 5.years.ago) }
      let!(:graduated_notification2_remaining_expired) do
        FactoryBot.create(:graduated_notification,
          :marked_remaining,
          organization: organization,
          bike: bike2,
          marked_remaining_at: Time.current - (2 * graduated_notification_interval))
      end
      let!(:graduated_notification2) do
        FactoryBot.create(:graduated_notification,
          bike: bike2,
          created_at: 3.weeks.ago,
          organization: organization)
      end

      # We were creating duplicate notifications! Test that we don't.
      it "doesn't enqueue what shouldn't be enqueued" do
        expect(graduated_notification_remaining_expired.most_recent?).to be_truthy
        expect(graduated_notification_remaining_expired.status).to eq "marked_remaining"

        expect(graduated_notification2_remaining_expired.reload.most_recent?).to be_falsey
        graduated_notification2.mark_remaining!
        graduated_notification2.update_column :marked_remaining_at, 2.weeks.ago
        graduated_notification2.reload
        bike2.reload
        expect(bike2.organizations.pluck(:id)).to eq([organization.id])
        expect(bike2.graduated?(organization)).to be_falsey
        expect(bike2.organization_graduated_notifications(organization).pluck(:id)).to match_array([graduated_notification2_remaining_expired.id, graduated_notification2.id])

        expect(GraduatedNotification.bikes_to_notify_without_notifications(organization).pluck(:id)).to eq([])
        expect(GraduatedNotification.bikes_to_notify_expired_notifications(organization).pluck(:id)).to eq([bike.id])
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([bike.id])

        Sidekiq::Testing.inline! do
          expect {
            instance.perform
            instance.perform
          }.to change(GraduatedNotification, :count).by 1
        end
        expect(graduated_notification_remaining_expired.reload.most_recent?).to be_falsey
      end
    end
  end
end
