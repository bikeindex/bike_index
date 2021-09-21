require "rails_helper"

RSpec.describe Admin::StolenNotificationsController, type: :request do
  base_url = "/admin/stolen_notifications"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      it "responds with OK and renders the index template" do
        get base_url

        expect(response.code).to eq "200"
        expect(response).to render_template(:index)
      end
    end

    describe "show" do
      it "responds with OK and renders the show template" do
        stolen_notification = FactoryBot.create(:stolen_notification)
        get "#{base_url}/#{stolen_notification.id}"

        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        expect(flash).to be_blank
      end
    end

    describe "resend" do
      it "resends the stolen notification" do
        Sidekiq::Worker.clear_all
        sender = FactoryBot.create(:user)
        stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
        expect {
          get "#{base_url}/#{stolen_notification.id}/resend"
        }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      end

      it "redirects if the stolen notification has already been sent" do
        Sidekiq::Worker.clear_all
        sender = FactoryBot.create(:user)
        stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
        stolen_notification.update_attribute :send_dates, [69].to_json

        expect {
          get "#{base_url}/#{stolen_notification.id}/resend"
        }.to change(EmailStolenNotificationWorker.jobs, :size).by(0)
        expect(response).to redirect_to(:admin_stolen_notification)
      end

      it "resends if the stolen notification has already been sent if we say pretty please" do
        Sidekiq::Worker.clear_all
        sender = FactoryBot.create(:user)
        stolen_notification = FactoryBot.create(:stolen_notification, sender: sender)
        stolen_notification.update_attribute :send_dates, [69].to_json

        expect {
          get "#{base_url}/#{stolen_notification.id}/resend?pretty_please=true"
        }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      end
    end
  end
end
