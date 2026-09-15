require "rails_helper"

RSpec.describe Notifications::Deliver do
  describe "track_email_delivery" do
    context "for a notification" do
      let(:user) { FactoryBot.create(:user) }
      let(:notification) { FactoryBot.create(:notification, kind: :confirmation_email, user:) }
      let(:user_email) { FactoryBot.create(:user_email, user:, email: user.email, confirmation_token: "xxxx") }

      it "adds email success" do
        expect(notification.reload.delivery_status).to eq "delivery_pending"
        Notifications::Deliver.track_email_delivery(notification) do
          CustomerMailer.confirmation_email(notification.user).deliver_now
        end
        expect(notification.reload.delivery_status).to eq "delivery_success"
        expect(notification.delivery_error).to be_nil
      end

      context "with user_email" do
        before { user_email.update(last_email_errored: true) }

        it "updates the user_email to be last_email_errored: false" do
          expect(user_email.reload).to be_valid
          expect(user_email.reload.last_email_errored?).to be_truthy
          expect(user.reload.email).to eq user_email.email
          expect(notification.reload.message_channel_target).to eq user.email
          user.update_column :updated_at, Time.current - 1.hour
          expect(notification.reload.delivery_status).to eq "delivery_pending"
          Notifications::Deliver.track_email_delivery(notification) do
            CustomerMailer.confirmation_email(notification.user).deliver_now
          end
          expect(notification.reload.delivery_status).to eq "delivery_success"
          expect(notification.delivery_error).to be_nil
          expect(user_email.reload.last_email_errored?).to be_falsey
          # it breaks the user cache
          expect(user.reload.updated_at).to be_within(2).of Time.current
        end
      end

      context "with an active email_ban" do
        let!(:email_ban) { FactoryBot.create(:email_ban, user:, reason: :honeypot) }

        it "doesn't deliver" do
          expect(EmailBan.ban?(user)).to be_truthy
          expect(notification.reload.delivery_status).to eq "delivery_pending"

          Notifications::Deliver.track_email_delivery(notification) { raise "delivered to a banned email!" }

          expect(notification.reload.delivery_status).to eq "delivery_banned"
          expect(Notification.delivery_failed.pluck(:id)).to eq([notification.id])
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end

        context "ended ban" do
          let!(:email_ban) do
            FactoryBot.create(:email_ban, user:, reason: :honeypot, end_at: Time.current - 1.hour)
          end

          it "delivers" do
            expect(EmailBan.ban?(user)).to be_falsey
            Notifications::Deliver.track_email_delivery(notification) do
              CustomerMailer.confirmation_email(notification.user).deliver_now
            end
            expect(notification.reload.delivery_status).to eq "delivery_success"
          end
        end

        context "admin notification about the banned user" do
          let(:marketplace_message) { FactoryBot.create(:marketplace_message, sender: user) }
          let(:notification) do
            FactoryBot.create(:notification, kind: :marketplace_message_blocked, user:,
              notifiable: marketplace_message)
          end

          it "delivers" do
            expect(EmailBan.ban?(user)).to be_truthy
            Notifications::Deliver.track_email_delivery(notification) do
              AdminMailer.blocked_marketplace_message_email(marketplace_message).deliver_now
            end
            expect(notification.reload.delivery_status).to eq "delivery_success"
            expect(ActionMailer::Base.deliveries.count).to eq 1
          end
        end
      end

      context "with the ban evaluation erroring" do
        let(:ban_error) { StandardError.new("email_domain lookup timed out") }
        before { allow(EmailBan).to receive(:ban?).and_raise(ban_error) }

        it "raises without recording a delivery failure" do
          expect(user_email.reload.last_email_errored?).to be_falsey

          expect {
            Notifications::Deliver.track_email_delivery(notification) { raise "should not be reached" }
          }.to raise_error(/timed out/)

          expect(notification.reload.delivery_status).to eq "delivery_pending"
          expect(notification.delivery_error).to be_nil
          expect(user_email.reload.last_email_errored?).to be_falsey
        end
      end

      context "with a delivery_error" do
        before { notification.update(delivery_status: "delivery_failure", delivery_error: "SomeErrorThing") }
        it "updates_delivery_status, doesn't remove delivery_error" do
          notification.reload
          Notifications::Deliver.track_email_delivery(notification) do
            CustomerMailer.confirmation_email(notification.user).deliver_now
          end
          expect(notification.reload.delivery_status).to eq "delivery_success"
          expect(notification.delivery_error).to eq "SomeErrorThing"
        end
      end

      context "sent a second time" do
        it "only delivers once" do
          expect(notification.reload.delivery_status).to eq "delivery_pending"
          Notifications::Deliver.track_email_delivery(notification) do
            CustomerMailer.confirmation_email(notification.user).deliver_now
          end
          expect(notification.reload.delivery_status).to eq "delivery_success"
          expect(ActionMailer::Base.deliveries.count).to eq 1

          Notifications::Deliver.track_email_delivery(notification) do
            CustomerMailer.confirmation_email(notification.user).deliver_now
          end
          expect(notification.reload.delivery_status).to eq "delivery_success"
          expect(ActionMailer::Base.deliveries.count).to eq 1
        end
      end

      context "with unknown postmark error" do
        it "raises and adds the error to the notification" do
          expect(notification.reload.delivery_status).to eq "delivery_pending"
          expect do
            expect do
              Notifications::Deliver.track_email_delivery(notification) do
                raise Postmark::ApiInputError.build("error", {"ErrorCode" => 499})
              end
            end.to raise_error(Postmark::ApiInputError)
          end.to change(EmailBan, :count).by 0

          expect(notification.reload.delivery_status).to eq "delivery_failure"
          expect(notification.delivery_error).to eq "Postmark::ApiInputError"
        end
      end

      context "with InactiveRecipientError" do
        let(:error_message) do
          "You tried to send to recipient(s) that have been marked as inactive. Found inactive addresses: " \
          "#{notification.message_channel_target}. Inactive recipients are ones that have generated a hard " \
          "bounce, a spam complaint, or a manual suppression."
        end
        let(:inactive_recipient_error) do
          Postmark::ApiInputError.build("error", {"ErrorCode" => 406, "Message" => error_message})
        end
        it "adds the error to the notification without banning, and doesn't deliver again" do
          expect(notification.reload.delivery_status).to eq "delivery_pending"
          expect do
            Notifications::Deliver.track_email_delivery(notification) { raise inactive_recipient_error }
          end.to change(EmailBan, :count).by 0

          expect(notification.reload.delivery_status).to eq "delivery_failure"
          expect(notification.delivery_error).to eq "Postmark::InactiveRecipientError"
          expect(EmailBan.ban?(user)).to be_falsey
          expect(notification.settled?).to be_truthy
          Notifications::Deliver.track_email_delivery(notification) { raise "should not be reached" }
        end

        context "with an error postmark didn't attribute" do
          let(:error_message) { "You tried to send to recipient(s) that have been marked as inactive." }
          before { user_email }

          it "records a failure, and flags the address" do
            expect(inactive_recipient_error.recipients).to eq([])
            Notifications::Deliver.track_email_delivery(notification) { raise inactive_recipient_error }

            # One address can't be part-delivered
            expect(notification.reload.delivery_status).to eq "delivery_failure"
            expect(user_email.reload.last_email_errored).to be_truthy
          end
        end
        context "when there is a user_email" do
          it "updates the user_email to be failed" do
            expect(user.reload.confirmed?).to be_falsey
            expect(user_email.reload).to be_valid
            expect(user_email.confirmed?).to be_falsey # this needs to work for unconfirmed emails too!
            expect(user_email.last_email_errored?).to be_falsey

            expect(notification.reload.delivery_status).to eq "delivery_pending"

            expect do
              Notifications::Deliver.track_email_delivery(notification) { raise inactive_recipient_error }
            end.to change(EmailBan, :count).by 0

            expect(notification.reload.delivery_status).to eq "delivery_failure"
            expect(notification.delivery_error).to eq "Postmark::InactiveRecipientError"

            expect(user_email.reload.last_email_errored).to be_truthy
            expect(EmailBan.ban?(user, user_email:)).to be_falsey
          end

          context "with an additional user_email" do
            let!(:additional_email) { FactoryBot.create(:user_email, user:) }
            before { user_email } # the user needs both addresses on file
            let(:notification) do
              FactoryBot.create(:notification, kind: :additional_email_confirmation,
                user:, notifiable: additional_email, message_channel_target: additional_email.email)
            end
            it "only records the error on the errored email" do
              expect do
                Notifications::Deliver.track_email_delivery(notification) { raise inactive_recipient_error }
              end.to change(EmailBan, :count).by 0

              expect(additional_email.reload.last_email_errored).to be_truthy
              expect(user_email.reload.last_email_errored).to be_falsey
            end
          end
        end
      end

      context "with InvalidEmailRequestError" do
        let(:invalid_email_error) { Postmark::ApiInputError.build("error", {"ErrorCode" => 300}) }
        it "adds the error to the notification without raising, and doesn't deliver again" do
          expect(notification.reload.delivery_status).to eq "delivery_pending"
          expect do
            Notifications::Deliver.track_email_delivery(notification) { raise invalid_email_error }
          end.to change(EmailBan, :count).by 0

          expect(notification.reload.delivery_status).to eq "delivery_failure"
          expect(notification.delivery_error).to eq "Postmark::InvalidEmailRequestError"
          expect(notification.delivery_error_invalid?).to be_truthy
          expect(notification.settled?).to be_truthy
          Notifications::Deliver.track_email_delivery(notification) { raise "should not be reached" }
        end
      end
    end
  end
end
