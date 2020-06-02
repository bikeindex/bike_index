require "rails_helper"

RSpec.describe GraduatedNotificationWorker, type: :lib do
  let(:instance) { described_class.new }
  # include_context :scheduled_worker
  # include_examples :scheduled_worker_tests

  # it "is the correct queue and frequency" do
  #   expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
  #   expect(described_class.frequency).to be > 23.hours
  # end

  describe "perform" do
    let(:graduated_notification_interval) { 1.year.to_i }
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: graduated_notification_interval) }
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, created_at: Time.current - (3 * graduated_notification_interval)) }

    describe "enqueue notifications" do
      it "enqueues notifications" do
        expect(organization.deliver_graduated_notifications?).to be_truthy
        Sidekiq::Worker.clear_all
        expect do
          instance.perform
        end.to change(described_class.jobs, :count).by 1
        expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([organization.id, bike.id])
      end
      context "organization does not have graduated_notification_interval" do
        let(:graduated_notification_interval) { 0 }
        it "does not enqueue notifications" do
          expect(organization.graduated_notification_interval).to be_blank
          expect(organization.deliver_graduated_notifications?).to be_falsey
          Sidekiq::Worker.clear_all
          expect do
            instance.perform
          end.to_not change(described_class.jobs, :count)
        end
      end
    end

    describe "create notification" do
      it "creates notification only once" do
        ActionMailer::Base.deliveries = []
        expect do
          instance.perform(organization.id, bike.id)
        end.to change(GraduatedNotification, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 1

        expect do
          instance.perform(organization.id, bike.id)
        end.to_not change(GraduatedNotification, :count)
        expect(ActionMailer::Base.deliveries.count).to eq 1
      end
    end

    it "schedules, creates and sends graduated_notification" do
      expect(bike.organizations.pluck(:id)).to eq([organization.id])
      expect(bike.graduated?(organization)).to be_falsey
      Sidekiq::Worker.clear_all
      ActionMailer::Base.deliveries = []
      Sidekiq::Testing.inline! do
        expect do
          instance.perform
        end.to change(GraduatedNotification, :count).by 1
      end
      graduated_notification = GraduatedNotification.last
      expect(graduated_notification.delivery_status).to eq "email_success"
      expect(graduated_notification.status).to eq "delivered"
      expect(graduated_notification.active?).to be_truthy
      expect(graduated_notification.primary_notification?).to be_truthy
      bike.reload
      expect(bike.organizations.pluck(:id)).to eq([])
      expect(bike.graduated?(organization)).to be_truthy

      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Renew your bike permit")
      expect(mail.to).to eq([bike.owner_email])
    end

    context "expired notification" do
      let!(:graduated_notification1) { FactoryBot.create(:graduated_notification, :marked_remaining, organization: organization, bike: bike) }
      it "schedules, creates and sends" do
        bike.reload
        expect(bike.graduated_notifications(organization).pluck(:id)).to eq([graduated_notification1.id])
        interval_start = Time.current - graduated_notification_interval
        expect(bike.created_at).to be < interval_start - graduated_notification_interval # Double interval early
        expect(graduated_notification1.created_at).to be < interval_start
        expect(graduated_notification1.marked_remaining_at).to be < interval_start
        expect(GraduatedNotification.count).to eq 1
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect do
            instance.perform
          end.to change(GraduatedNotification, :count).by 1
        end

        graduated_notification = GraduatedNotification.last
        expect(graduated_notification.delivery_status).to eq "email_success"
        expect(graduated_notification.status).to eq "delivered"
        expect(graduated_notification.active?).to be_truthy
        expect(graduated_notification.primary_notification?).to be_truthy
        bike.reload
        expect(bike.organizations.pluck(:id)).to eq([])
        expect(bike.graduated?(organization)).to be_truthy

        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Renew your bike permit")
        expect(mail.to).to eq([bike.owner_email])
      end
    end
  end
end
