require "rails_helper"

RSpec.describe Organized::OrganizationMessagesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/organization_messages" }
  include_context :request_spec_logged_in_as_organization_user

  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications], short_name: "UCLA") }
  let(:owner) { FactoryBot.create(:user_confirmed, notification_unstolen: true, preferred_language: "en") }
  let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: owner, creation_organization: current_organization) }
  let(:params) { {organization_message: {bike_id: bike.id, message: "Your lock is on the rack"}} }

  describe "create" do
    it "creates and sends an organization message to the owner" do
      Sidekiq::Job.clear_all
      expect {
        post base_url, params:
      }.to change(OrganizationMessage, :count).by(1)
      expect(flash[:success]).to be_present

      organization_message = OrganizationMessage.last
      expect(organization_message).to have_attributes(bike_id: bike.id, organization_id: current_organization.id,
        sender_id: current_user.id, receiver_id: owner.id, receiver_email: owner.email)

      EmailJobs::OrganizationMessageJob.drain
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([owner.email])
      expect(mail.reply_to).to eq([current_user.email])
      expect(mail.subject).to eq("Message from UCLA about your bike")
      expect(mail.text_part.body.to_s).to match(/from UCLA sent you a message about your bike/)
      expect(mail.text_part.body.to_s).to match("Your lock is on the rack")
      expect(mail.text_part.body.to_s).to_not match(/stolen/i)
      expect(organization_message.notifications.pluck(:kind, :user_id, :message_channel_target, :delivery_status))
        .to eq([["organization_message", owner.id, owner.email, "delivery_success"]])
      notification = organization_message.notifications.first
      expect(notification.sender).to eq current_user
      expect(Notification.notifications_sent_or_received_by(current_user)).to include(notification)
    end

    context "bike not registered with the organization" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }
      it "doesn't create" do
        expect {
          post base_url, params:
        }.to_not change(OrganizationMessage, :count)
        expect(flash[:error]).to match(/can't message the owner/)
      end
    end

    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: owner, creation_organization: current_organization) }
      it "doesn't create" do
        expect(bike.reload.organized?(current_organization)).to be_truthy
        expect {
          post base_url, params:
        }.to_not change(OrganizationMessage, :count)
        expect(flash[:error]).to be_present
      end
    end
  end
end
