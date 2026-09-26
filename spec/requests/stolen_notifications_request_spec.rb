require "rails_helper"

base_url = "/stolen_notifications"
RSpec.describe StolenNotificationsController, type: :request do
  let(:user2) { FactoryBot.create(:user) }
  let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user2) }
  let(:stolen_notification_attributes) do
    {
      bike_id: bike.id,
      message: "I saw this bike on the street!",
      reference_url: "https://party.com"
    }
  end

  describe "create" do
    it "fails without user logged in" do
      expect {
        post base_url, params: {stolen_notification: stolen_notification_attributes}
      }.not_to change(StolenNotification, :count)
    end

    describe "user logged in" do
      include_context :request_spec_logged_in_as_user
      let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: user2) }

      it "creates a Stolen Notification record" do
        expect(bike.reload.current_ownership.user_id).to eq user2.id
        expect(bike.contact_owner?(current_user)).to be_truthy
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect {
          expect {
            post base_url, params: {stolen_notification: stolen_notification_attributes}
            expect(flash[:success]).to be_present
          }.to change(StolenNotification, :count).by(1)
        }.to change(EmailJobs::StolenNotificationJob.jobs, :count).by(1)
        stolen_notification = StolenNotification.last
        expect(stolen_notification.bike).to eq bike
        expect(stolen_notification.sender_id).to eq current_user.id
        expect(stolen_notification.receiver_id).to eq user2.id
        expect(stolen_notification.message).to eq stolen_notification_attributes[:message]
        expect(stolen_notification.reference_url).to eq stolen_notification_attributes[:reference_url]
        expect(stolen_notification.kind).to eq "stolen_permitted"

        EmailJobs::StolenNotificationJob.drain
        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Stolen bike contact")
      end
      context "unstolen notification direct" do
        let(:owner_email) { "example@bikeindex.org" }
        let(:organization_unstolen) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
        let(:current_user) { FactoryBot.create(:organization_user, organization: organization_unstolen) }
        let(:organization) { FactoryBot.create(:organization, direct_unclaimed_notifications: true) }
        let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: owner_email) }
        it "creates and sends" do
          expect(bike.reload.current_ownership.claimed?).to be_falsey
          expect(bike.current_ownership.organization_direct_unclaimed_notifications?).to be_truthy
          expect(bike.owner_email).to eq owner_email
          expect(bike.contact_owner?).to be false
          expect(bike.contact_owner?(current_user)).to be_truthy
          expect(bike.contact_owner?(current_user)).to be_truthy
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          expect {
            expect {
              post base_url, params: {stolen_notification: stolen_notification_attributes}
              expect(flash[:success]).to be_present
            }.to change(StolenNotification, :count).by(1)
          }.to change(EmailJobs::StolenNotificationJob.jobs, :count).by(1)
          stolen_notification = StolenNotification.last
          expect(stolen_notification.bike).to eq bike
          expect(stolen_notification.sender_id).to eq current_user.id
          expect(stolen_notification.receiver_email).to eq owner_email
          expect(stolen_notification.message).to eq stolen_notification_attributes[:message]
          expect(stolen_notification.reference_url).to eq stolen_notification_attributes[:reference_url]
          expect(stolen_notification.kind).to eq "unstolen_unclaimed_permitted_direct"

          EmailJobs::StolenNotificationJob.drain
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Stolen bike contact")
          expect(stolen_notification.receiver_email).to eq owner_email
        end
      end
      context "unstolen notification to the sender's organization's registration" do
        let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications], short_name: "UCLA") }
        let(:current_user) { FactoryBot.create(:organization_user, organization:) }
        let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "owner@bikeindex.org") }
        it "sends an organization message to the owner" do
          expect(bike.reload.current_ownership.claimed?).to be_falsey
          expect(bike.current_ownership.organization_direct_unclaimed_notifications?).to be_falsey
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          expect {
            post base_url, params: {stolen_notification: stolen_notification_attributes}
            expect(flash[:success]).to be_present
          }.to change(StolenNotification, :count).by(1)
          stolen_notification = StolenNotification.last
          expect(stolen_notification.kind).to eq "unstolen_organization_permitted"
          expect(stolen_notification.receiver_email).to eq "owner@bikeindex.org"

          EmailJobs::StolenNotificationJob.drain
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.to).to eq(["owner@bikeindex.org"])
          expect(mail.subject).to eq("Message from UCLA about your bike")
          mail_text = mail.text_part.body.to_s
          expect(mail_text).to match(/from UCLA sent you a message/)
          expect(mail_text).to_not match(/stolen/i)
        end
        context "sent from another of the bike's organizations" do
          let(:organization2) { FactoryBot.create(:organization, short_name: "Rec Center") }
          before do
            FactoryBot.create(:organization_role_claimed, user: current_user, organization: organization2)
            FactoryBot.create(:bike_organization, bike:, organization: organization2)
          end
          it "sends from that organization" do
            post base_url, params: {stolen_notification: stolen_notification_attributes.merge(organization_id: organization2.id)}
            expect(StolenNotification.last.organization_id).to eq organization2.id

            EmailJobs::StolenNotificationJob.drain
            expect(ActionMailer::Base.deliveries.last.subject).to eq("Message from Rec Center about your bike")
          end
        end
      end
      context "not permitted notification" do
        let(:bike) { FactoryBot.create(:bike) }
        it "fails to create if the user isn't permitted to send a stolen_notification" do
          expect(bike.contact_owner?(current_user)).to be_falsey
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          expect {
            post base_url, params: {stolen_notification: stolen_notification_attributes}
          }.to_not change(StolenNotification, :count)
          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
