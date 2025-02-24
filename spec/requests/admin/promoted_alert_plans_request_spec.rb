require "rails_helper"

RSpec.describe Admin::PromotedAlertPlansController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:valid_params) do
      {
        name: "New Plan",
        amount_cents: 22_00,
        views: 5_000,
        duration_days: 7,
        amount_cents_facebook: 2200,
        ad_radius_miles: 25,
        active: true,
        description: "Cool plan that is cool",
        language: "en"
      }
    end
    let(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan) }

    describe "GET /admin/promoted_alert_plans" do
      it "responds with 200 OK and renders the index template" do
        plans = FactoryBot.create_list(:promoted_alert_plan, 3)

        get "/admin/promoted_alert_plans"

        expect(response).to be_ok
        expect(response).to render_template(:index)
        plans.each do |plan|
          expect(response.body).to include(plan.name)
        end
      end
    end

    describe "GET /admin/promoted_alert_plans/new" do
      it "responds with 200 OK and renders the new template" do
        get "/admin/promoted_alert_plans/new"
        expect(response).to be_ok
        expect(response).to render_template(:new)
      end
    end

    describe "POST /admin/promoted_alert_plans" do
      it "redirects to the index route on update success" do
        expect(PromotedAlertPlan.count).to eq(0)

        post "/admin/promoted_alert_plans",
          params: {promoted_alert_plan: valid_params}
        expect(PromotedAlertPlan.count).to eq(1)
        promoted_alert_plan = PromotedAlertPlan.first
        expect(response).to redirect_to(edit_admin_promoted_alert_plan_path(promoted_alert_plan))
        expect(flash[:errors]).to be_blank
        expect(promoted_alert_plan).to match_hash_indifferently valid_params
      end

      it "re-renders the edit template with a flash on update failure" do
        post "/admin/promoted_alert_plans", params: {promoted_alert_plan: {amount_cents: 22_00}}
        expect(response).to render_template(:new)
        expect(flash[:errors]).to include("Name can't be blank")
      end
    end

    describe "GET /admin/promoted_alert_plans/:id/edit" do
      it "responds with 200 OK and renders the edit template" do
        get "/admin/promoted_alert_plans/#{promoted_alert_plan.id}/edit"

        expect(response).to be_ok
        expect(response).to render_template(:edit)
        expect(response.body).to include(promoted_alert_plan.name)
      end
    end

    describe "PATCH /admin/promoted_alert_plans/:id" do
      it "redirects to the index route on update success" do
        patch "/admin/promoted_alert_plans/#{promoted_alert_plan.id}",
          params: {promoted_alert_plan: valid_params}

        expect(response).to redirect_to(admin_promoted_alert_plans_path)
        expect(flash[:errors]).to be_blank
        promoted_alert_plan.reload
        expect(promoted_alert_plan).to match_hash_indifferently valid_params
      end

      it "re-renders the edit template with a flash on update failure" do
        patch "/admin/promoted_alert_plans/#{promoted_alert_plan.id}",
          params: {promoted_alert_plan: {name: ""}}

        expect(response).to be_ok
        expect(response).to render_template(:edit)
        expect(flash[:errors]).to include("Name can't be blank")
      end
    end
  end

  context "given a logged-in non-superuser" do
    before { log_in }
    it { expect(get("/admin/promoted_alert_plans")).to eq(302) }
    it { expect(get("/admin/promoted_alert_plans/new")).to eq(302) }
    it { expect(post("/admin/promoted_alert_plans")).to eq(302) }
    it { expect(get("/admin/promoted_alert_plans/0/edit")).to eq(302) }
    it { expect(patch("/admin/promoted_alert_plans/0")).to eq(302) }
  end

  context "given a unauthenticated user" do
    it { expect(get("/admin/promoted_alert_plans")).to eq(302) }
    it { expect(get("/admin/promoted_alert_plans/new")).to eq(302) }
    it { expect(post("/admin/promoted_alert_plans")).to eq(302) }
    it { expect(get("/admin/promoted_alert_plans/0/edit")).to eq(302) }
    it { expect(patch("/admin/promoted_alert_plans/0")).to eq(302) }
  end
end
