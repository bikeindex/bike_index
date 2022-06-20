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
