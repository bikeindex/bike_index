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
      let(:sender) { FactoryBot.create(:user) }
      let(:stolen_notification_pre1) { FactoryBot.create(:stolen_notification, sender: sender) }
      let(:stolen_notification_pre2) { FactoryBot.create(:stolen_notification, sender: sender) }
      let(:stolen_notification) { FactoryBot.create(:stolen_notification, sender: sender) }
      before do
        EmailStolenNotificationWorker.new.perform(stolen_notification_pre1.id)
        EmailStolenNotificationWorker.new.perform(stolen_notification_pre2.id)
      end
      it "resends the stolen notification" do
        # To create the failed notification, happens async normally
        EmailStolenNotificationWorker.new.perform(stolen_notification.id)

        Sidekiq::Worker.clear_all
        expect(stolen_notification.reload.notifications.count).to eq 1
        expect(stolen_notification.notifications.delivery_success.count).to eq 1 # Because admin email was sent
        expect(stolen_notification.send_dates_parsed.count).to eq 0
        expect(stolen_notification.permitted_send?).to be_falsey
        expect(stolen_notification.kind).to eq "stolen_blocked"
        expect(Notification.count).to eq 3

        expect {
          get "#{base_url}/#{stolen_notification.id}/resend"
        }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)

        EmailStolenNotificationWorker.drain
        expect(Notification.count).to eq 4
        expect(stolen_notification.reload.notifications.count).to eq 2
        expect(stolen_notification.notifications.stolen_notification_sent.count).to eq 1
        expect(stolen_notification.send_dates_parsed.count).to eq 1
      end

      context "stolen_notification sent" do
        # Force send
        before { EmailStolenNotificationWorker.new.perform(stolen_notification.id, true) }

        it "redirects if the stolen notification has already been sent" do
          Sidekiq::Worker.clear_all
          expect(stolen_notification.reload.notifications.count).to eq 1
          expect(stolen_notification.send_dates_parsed.count).to eq 1
          expect(stolen_notification.kind).to eq "stolen_blocked"

          expect {
            get "#{base_url}/#{stolen_notification.id}/resend"
          }.to change(EmailStolenNotificationWorker.jobs, :size).by(0)
          expect(response).to redirect_to(:admin_stolen_notification)
          EmailStolenNotificationWorker.drain
          expect(stolen_notification.send_dates_parsed.count).to eq 1
        end

        it "resends if the stolen notification has already been sent if we say pretty please" do
          Sidekiq::Worker.clear_all
          expect(stolen_notification.reload.notifications.count).to eq 1

          expect {
            get "#{base_url}/#{stolen_notification.id}/resend?pretty_please=true"
          }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)

          EmailStolenNotificationWorker.drain
          expect(stolen_notification.reload.notifications.count).to eq 2
          expect(stolen_notification.send_dates_parsed.count).to eq 2
        end
      end
    end
  end
end
