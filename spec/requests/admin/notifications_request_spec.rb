require "rails_helper"

base_url = "/admin/notifications"
RSpec.describe Admin::NotificationsController, type: :request do
  context "logged in as superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:notifications)).to eq([])
      end

      context "with a notification" do
        let(:bike) { FactoryBot.create(:bike) }
        let!(:notification) { FactoryBot.create(:notification, bike:) }

        it "renders it" do
          get base_url
          expect(response.status).to eq(200)
          expect(assigns(:notifications).pluck(:id)).to eq([notification.id])
          expect(response.body).to include(admin_bike_path(bike.id, active_tab: "messages"))
        end
      end

      context "with search_bug_report_id" do
        let(:bug_report) { FactoryBot.create(:bug_report) }
        let!(:notification) { Notification.create!(kind: :bug_report_reply, notifiable: bug_report, sender: current_user, message_channel_target: bug_report.email) }
        let!(:notification_other) { FactoryBot.create(:notification) }

        it "lists the bug report's notifications, with their sender" do
          get base_url, params: {search_bug_report_id: bug_report.id}
          expect(assigns(:notifications).pluck(:id)).to eq([notification.id])
          expect(response.body).to include(admin_user_path(current_user.id))
        end
      end
    end
  end

  context "superuser ability" do
    include_context :request_spec_logged_in_as_user
    context "universal" do
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user) }
      it "gives access" do
        expect(superuser_ability.reload.kind).to eq "universal"
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:notifications)).to eq([])
      end
    end
    context "kind: controller" do
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "notifications") }
      it "gives access" do
        expect(superuser_ability.reload.kind).to eq "controller"
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:notifications)).to eq([])
      end
      context "not controller" do
        let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "bikes") }
        it "gives access" do
          expect(superuser_ability.reload.kind).to eq "controller"
          get base_url
          expect(response).to redirect_to user_root_url
        end
      end
    end
    context "kind: action" do
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "notifications", action_name: "index") }
      it "gives access" do
        expect(superuser_ability.reload.kind).to eq "action"
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:notifications)).to eq([])
      end
      context "not controller" do
        let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "notifications", action_name: "show") }
        it "gives access" do
          expect(superuser_ability.reload.kind).to eq "action"
          get base_url
          expect(response).to redirect_to user_root_url
        end
      end
    end
  end
end
