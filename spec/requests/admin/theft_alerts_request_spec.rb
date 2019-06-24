require "rails_helper"

RSpec.describe Admin::TheftAlertsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "GET /admin/theft_alerts" do
      it "responds with 200 OK and renders the index template" do
        get "/admin/theft_alerts"
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end

    describe "GET /admin/theft_alerts/:id/edit" do
      context "given a valid state transition param" do
        it "responds with 200 OK and renders the edit template" do
          alert = FactoryBot.create(:theft_alert)

          get "/admin/theft_alerts/#{alert.id}/edit", state_transition: :begin

          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
        end
      end

      context "given no state transition param" do
        it "redirects to the theft alert index page" do
          alert = FactoryBot.create(:theft_alert)

          get "/admin/theft_alerts/#{alert.id}/edit"

          expect(response).to redirect_to(admin_theft_alerts_path)
          expect(flash[:error]).to match(/invalid state/i)
        end
      end
    end

    describe "PATCH /admin/theft_alerts/:id" do
      it "redirects to the index route on state transition success" do
        alert = FactoryBot.create(:theft_alert)
        expect(alert.status).to eq("pending")

        patch "/admin/theft_alerts/#{alert.id}",
              state_transition: "begin",
              theft_alert: {
                facebook_post_url: "https://facebook.com/example/post/1",
                notes: "Some notes",
              }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(flash[:errors]).to be_blank
        expect(alert.reload.status).to eq("active")
        expect(alert.facebook_post_url).to eq("https://facebook.com/example/post/1")
        expect(alert.notes).to eq("Some notes")

        patch "/admin/theft_alerts/#{alert.id}",
              state_transition: "end",
              theft_alert: { status: true }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(flash[:errors]).to be_blank
        expect(alert.reload.status).to eq("inactive")

        patch "/admin/theft_alerts/#{alert.id}",
              state_transition: "reset",
              theft_alert: { status: true }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(flash[:errors]).to be_blank
        expect(alert.reload.status).to eq("pending")
      end

      it "redirects to the edit template on update failure" do
        alert = FactoryBot.create(:theft_alert, status: "pending")

        patch "/admin/theft_alerts/#{alert.id}",
              state_transition: "begin",
              theft_alert: { facebook_post_url: "" }

        expect(flash[:success]).to be_blank
        expect(flash[:error]).to include("Facebook post url must be a valid url")
        expect(response).to redirect_to(edit_admin_theft_alert_path(alert, params: { state_transition: :begin }))
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
