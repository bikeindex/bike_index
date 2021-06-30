require "rails_helper"

base_url = "/user_alerts"
RSpec.describe UserAlertsController, type: :request do
  let(:user_alert) { FactoryBot.create(:user_alert, kind: "unassigned_bike_org", bike: FactoryBot.create(:bike)) }

  describe "update" do
    describe "dismiss" do
      it "does not dismiss" do
        expect(user_alert.dismissable?).to be_truthy
        expect(user_alert.user_id).to be_present
        expect(user_alert.dismissed?).to be_falsey
        patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
        expect(response).to redirect_to "/session/new"
        expect(flash).to be_present
        expect(user_alert.reload.dismissed?).to be_falsey
      end
      context "signed in" do
        include_context :request_spec_logged_in_as_user
        it "does not dismiss" do
          expect(user_alert.dismissable?).to be_truthy
          expect(user_alert.user_id).to_not eq current_user.id
          expect(user_alert.dismissed?).to be_falsey
          patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
          expect(response).to redirect_to "/my_account"
          expect(flash[:error]).to be_present
          expect(user_alert.reload.dismissed?).to be_falsey
        end
        context "user's alert" do
          let(:current_user) { user_alert.user }
          it "dismisses" do
            expect(user_alert.dismissable?).to be_truthy
            expect(user_alert.user_id).to eq current_user.id
            expect(user_alert.dismissed?).to be_falsey
            patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
            expect(response).to redirect_to "/my_account"
            expect(flash).to be_blank
            expect(user_alert.reload.dismissed?).to be_truthy
            dismissed_time = Time.current - 1.day
            user_alert.update(dismissed_at: dismissed_time)
            # And dismiss without failing again
            patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
            expect(response).to redirect_to "/my_account"
            expect(flash).to be_blank
            expect(user_alert.reload.dismissed_at).to be_within(1).of dismissed_time
            # And unknown action errors
            patch "#{base_url}/#{user_alert.id}", params: { action: "party" }
            expect(response).to redirect_to "/my_account"
            expect(flash[:error]).to be_present
          end
          context "resolved alert" do
            it "doesn't make a fuss" do
              expect(user_alert.dismissable?).to be_truthy
              user_alert.resolve!
              expect(user_alert.reload.resolved?).to be_truthy
              expect(user_alert.dismissed?).to be_falsey
              patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
              expect(response).to redirect_to "/my_account"
              expect(flash).to be_blank
              expect(user_alert.reload.resolved?).to be_truthy
              expect(user_alert.dismissed?).to be_falsey
            end
          end
          context "not dismissable" do
            let(:user_alert) { FactoryBot.create(:user_alert) }
            it "flash errors" do
              expect(user_alert.reload.dismissable?).to be_falsey
              expect(user_alert.dismissed?).to be_falsey
              expect(user_alert.user_id).to eq current_user.id
              patch "#{base_url}/#{user_alert.id}", params: { action: "dismiss" }
              expect(response).to redirect_to "/my_account"
              expect(flash[:error]).to be_present
              expect(user_alert.dismissed?).to be_falsey
            end
          end
        end
      end
    end
  end
end
