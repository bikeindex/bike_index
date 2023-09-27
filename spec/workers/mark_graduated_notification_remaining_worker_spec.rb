require "rails_helper"

RSpec.describe MarkGraduatedNotificationRemainingWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:graduated_notification_interval) { 2.years.to_i }
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: ["graduated_notifications"],
        graduated_notification_interval: graduated_notification_interval)
    end
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:graduated_notification1) { FactoryBot.build(:graduated_notification, :with_user, organization: organization, user: user) }
    let!(:bike1) { graduated_notification1.bike }
    context "user_registration_organization deleted" do
      let(:user_registration_organization) { FactoryBot.create(:user_registration_organization, user: user, organization: organization, all_bikes: true) }
      # I'm worried about unfinished processing of mark_remaining.
      # This is one scenario
      it "deletes a bike and associations, doesn't error if bike is deleted already" do
        expect(user_registration_organization.reload.bikes.pluck(:id)).to eq([bike1.id])
        AfterUserChangeWorker.new.perform(user.id)
        graduated_notification1.save
        expect(graduated_notification1.reload.user).to be_present
        expect(graduated_notification1.processed?).to be_falsey
        expect(graduated_notification1.send_email?).to be_truthy
        expect(graduated_notification1.user_registration_organization&.id).to eq user_registration_organization.id
        expect(bike1.reload.bike_organizations.count).to eq 1
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect(GraduatedNotification.count).to eq 1
        graduated_notification1.process_notification
        graduated_notification1.reload
        expect(graduated_notification1.status).to eq "bike_graduated"
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.send_email?).to be_truthy
        expect(UserRegistrationOrganization.count).to eq 0
        expect(UserRegistrationOrganization.unscoped.count).to eq 1

        # Verify that we aren't creating bonus jobs
        expect {
          instance.perform(graduated_notification1.id)
        }.to_not change(described_class.jobs, :count)

        expect(UserRegistrationOrganization.count).to eq 1
        expect(UserRegistrationOrganization.unscoped.count).to eq 1
        expect(graduated_notification1.reload.status).to eq "marked_remaining"

        # Just in case things failed partway through, verify it runs again
        user_registration_organization.update_column :deleted_at, Time.current
        expect(UserRegistrationOrganization.count).to eq 0
        instance.perform(graduated_notification1.id)

        expect(graduated_notification1.reload.status).to eq "marked_remaining"
        expect(UserRegistrationOrganization.count).to eq 1
        expect(UserRegistrationOrganization.unscoped.count).to eq 1
      end
    end
  end
end
