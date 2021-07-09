require "rails_helper"

base_url = "/admin/theft_alerts"

RSpec.describe Admin::TheftAlertsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "GET /admin/theft_alerts" do
      let!(:theft_alert) { FactoryBot.create(:theft_alert) }
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
      let(:target_timezone) { ActiveSupport::TimeZone["Pacific Time (US & Canada)"] }
      context "period of one day" do
        it "renders the period expected" do
          get base_url, params: {period: "day", timezone: "Pacific Time (US & Canada)"}
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          Time.zone = target_timezone
          expect(assigns(:start_time).to_i).to be_within(1).of((Time.current.beginning_of_day - 1.day).to_i)
          expect(assigns(:end_time).to_i).to be_within(1).of Time.current.to_i
        end
      end
      context "custom without end_time" do
        let(:start_time) { Time.at(1577050824) } # 2019-12-22 15:40:50 UTC
        it "renders the period expected" do
          get base_url, params: {period: "custom", start_time: start_time.to_i, end_time: ""}
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          expect(assigns(:period)).to eq "custom"
          expect(assigns(:start_time)).to be_within(1.second).of start_time
          expect(assigns(:end_time)).to be_within(2.seconds).of Time.current
        end
      end
      context "reversed period" do
        let(:start_time) { Time.at(1577050824) } # 2019-12-22 15:40:50 UTC
        let(:end_time) { Time.at(1515448980) } # 2018-01-08 14:03:00 -0800
        it "renders the period expected" do
          get base_url, params: {
            period: "custom",
            start_time: start_time.to_i,
            end_time: "2018-01-08T14:03",
            timezone: "Pacific Time (US & Canada)"
          }
          expect(response.code).to eq "200"
          expect(response).to render_template(:index)
          expect(assigns(:period)).to eq "custom"
          expect(assigns(:start_time)).to be_within(2.seconds).of end_time
          expect(assigns(:end_time)).to be_within(2.seconds).of start_time
        end
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
          params: {
            theft_alert: {
              status: "active",
              theft_alert_plan_id: alert.theft_alert_plan.id,
              notes: "Some notes"
            }
          }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(flash[:success]).to match(/success/i)
        expect(flash[:errors]).to be_blank
        expect(alert.reload.status).to eq("active")
        expect(alert.notes).to eq("Some notes")
      end

      it "sets alert timestamps when beginning an alert" do
        alert = FactoryBot.create(:theft_alert)
        expect(alert.status).to eq("pending")
        expect(alert.begin_at).to eq(nil)
        expect(alert.end_at).to eq(nil)

        patch "/admin/theft_alerts/#{alert.id}",
          params: {
            theft_alert: {
              status: "active",
              theft_alert_plan_id: alert.theft_alert_plan.id
            }
          }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(alert.reload.status).to eq("active")
        expect(alert.begin_at).to be_within(2.seconds).of(Time.current)
        expect(alert.end_at).to be_within(2.seconds).of(Time.current + 7.days)
      end

      it "does not set alert timestamps when updating a pending alert" do
        alert = FactoryBot.create(:theft_alert)
        expect(alert.status).to eq("pending")
        expect(alert.notes).to be_nil
        expect(alert.begin_at).to be_nil
        expect(alert.end_at).to be_nil

        patch "/admin/theft_alerts/#{alert.id}",
          params: {
            theft_alert: {
              status: "pending",
              theft_alert_plan_id: alert.theft_alert_plan.id,
              notes: "updated note"
            }
          }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(alert.reload.status).to eq("pending")
        expect(alert.notes).to eq("updated note")
        expect(alert.begin_at).to be_nil
        expect(alert.end_at).to be_nil
      end

      it "does not overwrite submitted timestamps when updating a non-pending alert" do
        alert = FactoryBot.create(:theft_alert_begun)
        now = Time.current
        expect(alert.status).to eq("active")

        patch "/admin/theft_alerts/#{alert.id}",
          params: {
            theft_alert: {
              status: "active",
              theft_alert_plan_id: alert.theft_alert_plan.id,
              begin_at: now,
              end_at: now + 1.day
            }
          }

        expect(response).to redirect_to(admin_theft_alerts_path)
        expect(alert.reload.status).to eq("active")
        expect(alert.begin_at).to be_within(5.seconds).of(now)
        expect(alert.end_at).to be_within(5.seconds).of(now + 1.day)
      end

      it "renders the edit template on update failure" do
        alert = FactoryBot.create(:theft_alert, status: "pending")

        patch "/admin/theft_alerts/#{alert.id}",
          params: {
            theft_alert: {
              status: nil,
              theft_alert_plan_id: alert.theft_alert_plan.id
            }
          }

        expect(response.status).to eq(200)
        expect(flash[:success]).to be_blank
        expect(flash[:error]).to include("Status can't be blank")
        expect(alert.reload.status).to eq("pending")
      end
    end

    describe "enqueing jobs" do
      let(:theft_alert) { FactoryBot.create(:theft_alert, status: "pending") }
      context "activate_theft_alert" do
        it "enqueues the activate_theft_alert job" do
          expect(theft_alert.reload.activating_at).to be_blank
          expect(theft_alert.activating?).to be_falsey
          Sidekiq::Worker.clear_all
          patch "/admin/theft_alerts/#{theft_alert.id}", params: {activate_theft_alert: 1}
          expect(ActivateTheftAlertWorker.jobs.count).to eq 1
          expect(theft_alert.reload.activating_at).to be_present
          expect(theft_alert.activating?).to be_truthy
        end
      end
      context "update_theft_alert" do
        it "enqueues the job" do
          expect(theft_alert.reload.activating_at).to be_blank
          Sidekiq::Worker.clear_all
          patch "/admin/theft_alerts/#{theft_alert.id}", params: {update_theft_alert: true}
          expect(UpdateTheftAlertFacebookWorker.jobs.count).to eq 1
          expect(theft_alert.reload.activating_at).to be_blank
        end
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
