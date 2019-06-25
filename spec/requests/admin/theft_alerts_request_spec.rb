require "rails_helper"

RSpec.describe Admin::TheftAlertsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "GET /admin/theft_alerts" do
      let!(:theft_alert) { FactoryBot.create(:theft_alert) }
      it "responds with 200 OK and renders the index template" do
        get "/admin/theft_alerts"
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end

    describe "GET /admin/theft_alerts/:id/edit" do
      it "responds with 200 and the edit template" do
        alert = FactoryBot.create(:theft_alert)

        get "/admin/theft_alerts/#{alert.id}/edit"

        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "PATCH /admin/theft_alerts/:id" do
      it "redirects to the index route on update success" do
        alert = FactoryBot.create(:theft_alert)
        expect(alert.status).to eq("pending")

        patch "/admin/theft_alerts/#{alert.id}",
              theft_alert: {
                status: "active",
                facebook_post_url: "https://facebook.com/example/post/1",
                theft_alert_plan_id: alert.theft_alert_plan.id,
                notes: "Some notes",
              }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(flash[:success]).to match(/success/i)
        expect(flash[:errors]).to be_blank
        expect(alert.reload.status).to eq("active")
        expect(alert.facebook_post_url).to eq("https://facebook.com/example/post/1")
        expect(alert.notes).to eq("Some notes")
      end

      it "sets alert timestamps when beginning an alert" do
        alert = FactoryBot.create(:theft_alert)
        expect(alert.status).to eq("pending")
        expect(alert.begin_at).to eq(nil)
        expect(alert.end_at).to eq(nil)

        patch "/admin/theft_alerts/#{alert.id}",
              theft_alert: {
                status: "active",
                facebook_post_url: "https://facebook.com/example/post/1",
                theft_alert_plan_id: alert.theft_alert_plan.id,
              }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(alert.reload.status).to eq("active")
        expect(alert.begin_at).to be_within(2.seconds).of(Time.current)
        expect(alert.end_at).to be_within(2.seconds).of(Time.current + 7.days)
      end

      it "does not overwrite submitted timestamps when updating a non-pending alert" do
        alert = FactoryBot.create(:theft_alert_begun)
        now = Time.current
        expect(alert.status).to eq("active")

        patch "/admin/theft_alerts/#{alert.id}",
              theft_alert: {
                status: "active",
                facebook_post_url: "https://facebook.com/example/post/1",
                theft_alert_plan_id: alert.theft_alert_plan.id,
                begin_at: now,
                end_at: now + 1.day,
              }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(alert.reload.status).to eq("active")
        expect(alert.begin_at).to be_within(5.seconds).of(now)
        expect(alert.end_at).to be_within(5.seconds).of(now + 1.day)
      end

      it "renders the edit template on update failure" do
        alert = FactoryBot.create(:theft_alert, status: "pending")

        patch "/admin/theft_alerts/#{alert.id}",
              theft_alert: {
                status: nil,
                theft_alert_plan_id: alert.theft_alert_plan.id,
              }

        expect(response.status).to eq(200)
        expect(flash[:success]).to be_blank
        expect(flash[:error]).to include("Status can't be blank")
        expect(alert.reload.status).to eq("pending")
      end
    end
  end

  context "given a logged-in non-superuser" do
    before { log_in }
    it { expect(get("/admin/theft_alerts")).to eq(302) }
    it { expect(get("/admin/theft_alerts/0/edit")).to eq(302) }
    it { expect(patch("/admin/theft_alerts/0")).to eq(302) }
  end

  context "given a unauthenticated user" do
    it { expect(get("/admin/theft_alerts")).to eq(302) }
    it { expect(get("/admin/theft_alerts/0/edit")).to eq(302) }
    it { expect(patch("/admin/theft_alerts/0")).to eq(302) }
  end
end
