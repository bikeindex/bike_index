require "rails_helper"

base_url = "/user_alerts"
RSpec.describe UserAlertsController, type: :request do
  let(:organization_id) { nil } # Ignore, because we don't generally need it
  let(:bike) { FactoryBot.create(:bike) }
  let(:alert_user) { FactoryBot.create(:user_confirmed) }
  let(:kind) { "unassigned_bike_org" }
  let(:user_alert) { FactoryBot.create(:user_alert, user: alert_user, kind: kind, bike: bike, organization_id: organization_id) }

  describe "update" do
    before { host! "bikeindex.org" } # I do not know why the host is getting fucked with in here :(
    describe "dismiss" do
      it "does not dismiss" do
        expect(user_alert.dismissable?).to be_truthy
        expect(user_alert.user_id).to be_present
        expect(user_alert.dismissed?).to be_falsey
        patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"}
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
          patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"}
          expect(response).to redirect_to "/my_account"
          expect(flash[:error]).to be_present
          expect(user_alert.reload.dismissed?).to be_falsey
        end
        context "user's alert" do
          let(:alert_user) { current_user }
          it "dismisses" do
            expect(user_alert.dismissable?).to be_truthy
            expect(user_alert.user_id).to eq current_user.id
            expect(user_alert.dismissed?).to be_falsey
            patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"}
            expect(response).to redirect_to "/my_account"
            expect(flash).to be_blank
            expect(user_alert.reload.dismissed?).to be_truthy
            dismissed_time = Time.current - 1.day
            user_alert.update(dismissed_at: dismissed_time)
            # And dismiss without failing again
            patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"},
              headers: {"HTTP_REFERER" => "http://bikeindex.org/bikes"}
            expect(response).to redirect_to "/bikes"
            expect(flash).to be_blank
            expect(user_alert.reload.dismissed_at).to be_within(1).of dismissed_time
            # And unknown action errors
            patch "#{base_url}/#{user_alert.id}", params: {alert_action: "party"}
            expect(response).to redirect_to "/my_account"
            expect(flash[:error]).to be_present
          end
          context "resolved alert" do
            it "doesn't make a fuss" do
              expect(user_alert.dismissable?).to be_truthy
              user_alert.resolve!
              expect(user_alert.reload.resolved?).to be_truthy
              expect(user_alert.dismissed?).to be_falsey
              patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"}
              expect(response).to redirect_to "/my_account"
              expect(flash).to be_blank
              expect(user_alert.reload.resolved?).to be_truthy
              expect(user_alert.dismissed?).to be_falsey
            end
          end
          context "not dismissable" do
            let(:kind) { "phone_waiting_confirmation" }
            it "flash errors" do
              expect(user_alert.reload.dismissable?).to be_falsey
              expect(user_alert.dismissed?).to be_falsey
              expect(user_alert.user_id).to eq current_user.id
              patch "#{base_url}/#{user_alert.id}", params: {alert_action: "dismiss"}
              expect(response).to redirect_to "/my_account"
              expect(flash[:error]).to be_present
              expect(user_alert.dismissed?).to be_falsey
            end
          end
        end
      end
    end
    describe "add_bike_organization" do
      include_context :request_spec_logged_in_as_user
      let(:alert_user) { current_user }
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike, :with_ownership, user: current_user) }
      let(:organization_id) { organization.id }
      it "adds an organization" do
        user_alert.reload
        expect(user_alert.organization_id).to eq organization.id
        bike.reload
        expect(bike.claimed?).to be_falsey
        expect(current_user.authorized?(bike)).to be_truthy
        expect(bike.organizations.pluck(:id)).to eq([])
        expect(bike.send(:editable_organization_ids)).to eq([])
        expect(current_user.alert_slugs).to eq([])
        CallbackJob::AfterUserChangeJob.new.perform(current_user.id)
        user_alert.reload
        current_user.reload
        expect(current_user.alert_slugs).to eq(["unassigned_bike_org"])
        Sidekiq::Job.clear_all
        patch "#{base_url}/#{user_alert.to_param}", params: {add_bike_organization: "true"},
          headers: {"HTTP_REFERER" => "http://bikeindex.org/my_account"}
        expect(CallbackJob::AfterUserChangeJob.jobs.count).to eq 1
        expect(response).to redirect_to "/my_account"
        expect(flash).to be_blank
        bike.reload
        expect(bike.claimed?).to be_falsey
        expect(bike.organizations.pluck(:id)).to match_array([organization.id])
        expect(bike.send(:editable_organization_ids)).to match_array([organization.id])

        user_alert.reload
        expect(user_alert.resolved?).to be_truthy
      end
    end
  end
end
