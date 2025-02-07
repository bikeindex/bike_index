require "rails_helper"

RSpec.describe Notification, type: :model do
  describe "sender_display_name" do
    let(:payment) { FactoryBot.create(:payment) }
    let(:notification) { FactoryBot.create(:notification, kind: "donation_stolen", notifiable: payment, user: payment.user) }
    it "is payment" do
      expect(notification.sender_display_name).to eq "auto"
    end
  end

  describe "notifications_sent_or_received_by" do
    let(:user) { FactoryBot.create(:user) }
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let(:stolen_notification) { FactoryBot.create(:stolen_notification, sender: user, bike: bike) }
    let!(:notification1) { FactoryBot.create(:notification, user: user) }
    it "gets from and by" do
      expect {
        EmailStolenNotificationWorker.new.perform(stolen_notification.id)
        EmailStolenNotificationWorker.new.perform(stolen_notification.id, true)
      }.to change(Notification, :count).by 2

      expect(Notification.pluck(:kind)).to match_array(%w[confirmation_email stolen_notification_sent stolen_notification_blocked])

      expect(Notification.notifications_sent_or_received_by(user).pluck(:id).uniq.count).to eq 3
      expect(Notification.notifications_sent_or_received_by(user.id).pluck(:id).uniq.count).to eq 3
    end
  end

  describe "message_channel_target and calculated_email" do
    let(:notification) { FactoryBot.create(:notification, user: user) }
    let(:user) { FactoryBot.create(:user, email: "stuff@party.eu") }
    it "returns email, if possible" do
      expect(notification.reload.message_channel_target).to be_nil
      expect(notification.send(:calculated_email)).to eq "stuff@party.eu"
      expect(notification.send(:calculated_message_channel_target)).to eq "stuff@party.eu"
      expect(notification.delivery_status).to eq "delivery_pending"
      user.destroy
      expect(notification.reload.send(:calculated_email)).to be_nil
      expect(notification.message_channel_target).to be_nil
    end
    context "bike deleted" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:notification) { FactoryBot.create(:notification, kind: :finished_registration, bike: bike, user: nil) }
      it "still finds" do
        expect(notification.reload.message_channel_target).to be_nil
        expect(notification.send(:calculated_message_channel_target)).to eq bike.owner_email
        bike.destroy
        expect(notification.reload.message_channel_target).to be_nil
        expect(notification.send(:calculated_message_channel_target)).to eq bike.owner_email
      end
    end
    context "email delivered" do
      before { notification.update(delivery_status: "delivery_success", message_channel: "email") }
      it "returns email" do
        expect(notification.delivery_status).to eq "delivery_success"
        expect(notification.send(:calculated_email)).to eq "stuff@party.eu"
        expect(notification.message_channel_target).to eq "stuff@party.eu"
      end
    end
    context "email delivered" do
      let(:user_phone) { FactoryBot.create(:user_phone, user: user) }
      let(:notification) { FactoryBot.create(:notification, kind: :phone_verification, notifiable: user_phone) }
      it "returns email" do
        expect(notification).to be_valid
        expect(notification.send(:calculated_message_channel_target)).to eq user_phone.phone
        expect(notification.message_channel_target).to be_nil

        notification.update(delivery_status: "delivery_success", message_channel: "email")
        expect(notification.send(:calculated_message_channel_target)).to eq user_phone.phone
        expect(notification.message_channel_target).to eq user_phone.phone
      end
    end
  end

  describe "kind sanity checks" do
    it "doesn't have duplicates" do
      expect(Notification::KIND_ENUM.values.sort).to eq Notification::KIND_ENUM.values.uniq.sort
      expect(Notification::KIND_ENUM.keys.sort).to eq Notification::KIND_ENUM.keys.uniq.sort
    end
  end

  describe "sender" do
    let(:notification) { Notification.new(notifiable: notifiable, kind: kind) }
    context "donation" do
      let(:notifiable) { Payment.new }
      let(:kind) { "donation_stolen" }
      it "is auto" do
        expect(notification.sender).to be_blank
      end
    end
    context "customer_contact" do
      let(:user) { User.new(id: 12) }
      let(:notifiable) { CustomerContact.new(creator: user) }
      let(:kind) { "stolen_contact" }
      it "is auto" do
        expect(notification.sender).to eq user
      end
    end
    context "stolen_notification" do
      let(:user) { User.new(id: 12) }
      let(:notifiable) { StolenNotification.new(sender: user) }
      let(:kind) { "stolen_notification_sent" }
      it "is auto" do
        expect(notification.sender).to eq user
      end
    end
    context "user_alert" do
      let(:notifiable) { UserAlert.new(id: 12) }
      let(:kind) { "stolen_notification_sent" }
      it "is auto" do
        expect(notification.sender).to be_blank
      end
    end
  end

  describe "theft_survey_4_2022" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record) }
    let(:user) { bike.owner }
    it "is valid" do
      expect(bike.reload.status).to eq "status_stolen"
      notification = Notification.create(user: user, kind: "theft_survey_4_2022", notifiable: bike.current_stolen_record)
      expect(notification).to be_valid
    end
  end

  describe "theft_survey_2023" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:user) { bike.owner }
    it "is valid" do
      notification = Notification.create(user: user, kind: "theft_survey_2023", bike: bike)
      expect(notification).to be_valid
      expect(notification.survey_id).to eq 1
      expect(bike.reload.theft_surveys.pluck(:id)).to eq([notification.id])
    end
    context "no user" do
      let(:bike) { FactoryBot.create(:bike, owner_email: "something@stuff.com") }
      it "is valid" do
        notification = Notification.create(kind: "theft_survey_2023", bike: bike)
        expect(notification).to be_valid
        expect(notification.survey_id).to eq 1
        expect(notification.send(:calculated_message_channel_target)).to eq "something@stuff.com"
        expect(bike.reload.theft_surveys.pluck(:id)).to eq([notification.id])
      end
    end
  end

  describe "track_email_delivery" do
    let(:notification) { FactoryBot.create(:notification, kind: :confirmation_email) }

    it "adds email success" do
      expect(notification.reload.delivery_status).to eq "delivery_pending"
      notification.track_email_delivery do
        CustomerMailer.confirmation_email(notification.user).deliver_now
      end
      expect(notification.reload.delivery_status).to eq "delivery_success"
      expect(notification.delivery_error).to be_nil
    end

    context "sent a second time" do
      it "only delivers once" do
        expect(notification.reload.delivery_status).to eq "delivery_pending"
        notification.track_email_delivery do
          CustomerMailer.confirmation_email(notification.user).deliver_now
        end
        expect(notification.reload.delivery_status).to eq "delivery_success"
        expect(ActionMailer::Base.deliveries.count).to eq 1

        notification.track_email_delivery do
          CustomerMailer.confirmation_email(notification.user).deliver_now
        end
        expect(notification.reload.delivery_status).to eq "delivery_success"
        expect(ActionMailer::Base.deliveries.count).to eq 1
      end
    end

    context "when email delivery fails" do
      let(:error_message) do
        "You tried to send to recipient(s) that have been marked as inactive. Found inactive addresses: example@bikeindex.org. " \
        "Inactive recipients are ones that have generated a hard bounce, a spam complaint, or a manual suppression."
      end
      it "adds the error message to the notification" do
        expect(notification.reload.delivery_status).to eq "delivery_pending"
        expect do
          notification.track_email_delivery do
            raise Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => error_message})
          end
        end.to raise_error(Postmark::InactiveRecipientError)

        expect(notification.reload.delivery_status).to eq "delivery_failure"
        expect(notification.delivery_error).to eq "Postmark::InactiveRecipientError"
      end
    end
  end
end
