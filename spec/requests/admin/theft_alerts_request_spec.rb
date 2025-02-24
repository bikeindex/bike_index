require "rails_helper"

base_url = "/admin/promoted_alerts"

RSpec.describe Admin::PromotedAlertsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, approved: true) }
    let(:bike) { stolen_record.bike }

    describe "GET /admin/promoted_alerts" do
      let!(:promoted_alert) { FactoryBot.create(:promoted_alert) }
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

    describe "GET /admin/promoted_alerts/:id/edit" do
      it "responds with 200 and the edit template" do
        promoted_alert = FactoryBot.create(:promoted_alert)

        get "/admin/promoted_alerts/#{promoted_alert.id}/edit"

        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "PATCH /admin/promoted_alerts/:id" do
      it "redirects to the index route on update success" do
        promoted_alert = FactoryBot.create(:promoted_alert)
        expect(promoted_alert.status).to eq("pending")

        patch "/admin/promoted_alerts/#{promoted_alert.id}",
          params: {
            promoted_alert: {update_promoted_alert: true, notes: "Some notes"}
          }

        expect(response).to redirect_to(admin_promoted_alerts_path)
        expect(flash[:success]).to match(/success/i)
        expect(flash[:errors]).to be_blank
        expect(promoted_alert.reload.notes).to eq("Some notes")
      end
    end

    describe "enqueing jobs" do
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, status: "pending") }
      context "activate_promoted_alert" do
        it "enqueues the activate_promoted_alert job" do
          expect(promoted_alert.reload.activating_at).to be_blank
          expect(promoted_alert.activating?).to be_falsey
          Sidekiq::Job.clear_all
          patch "/admin/promoted_alerts/#{promoted_alert.id}", params: {activate_promoted_alert: 1}
          expect(StolenBike::ActivatePromotedAlertJob.jobs.count).to eq 1
          expect(promoted_alert.reload.activating_at).to be_present
          expect(promoted_alert.activating?).to be_truthy
        end
      end
      context "update_promoted_alert" do
        it "enqueues the job" do
          expect(promoted_alert.reload.activating_at).to be_blank
          Sidekiq::Job.clear_all
          patch "/admin/promoted_alerts/#{promoted_alert.id}", params: {update_promoted_alert: true}
          # expect(StolenBike::UpdatePromotedAlertFacebookJob.jobs.count).to eq 1
          expect(promoted_alert.reload.activating_at).to be_blank
        end
      end
    end

    describe "new" do
      let!(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan) }
      it "renders" do
        expect(stolen_record).to be_present
        get "#{base_url}/new?bike_id=#{bike.id}"
        expect(assigns(:stolen_record)&.id).to eq stolen_record.id
        expect(response).to be_ok
        expect(response).to render_template(:new)
        get "#{base_url}/new"
        expect(response).to redirect_to admin_promoted_alerts_path
        expect(flash[:info]).to match "bike"
      end
    end

    describe "create" do
      let!(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan) }
      it "creates and activates" do
        Sidekiq::Job.clear_all
        expect do
          post "/admin/promoted_alerts",
            params: {
              promoted_alert: {
                stolen_record_id: stolen_record.id,
                promoted_alert_plan_id: promoted_alert_plan.id,
                notes: "Some notes",
                ad_radius_miles: 33
              }
            }
        end.to change(PromotedAlert, :count).by 1

        expect(flash[:success]).to be_present
        promoted_alert = PromotedAlert.last
        expect(promoted_alert.admin).to be_truthy
        expect(promoted_alert.user_id).to eq current_user.id
        expect(promoted_alert.stolen_record_id).to eq stolen_record.id
        expect(promoted_alert.bike_id).to eq bike.id
        expect(promoted_alert.ad_radius_miles).to eq 33
        expect(promoted_alert.notes).to eq "Some notes"
        expect(promoted_alert.status).to eq "pending"
        expect(promoted_alert.activateable?).to be_truthy
        expect(StolenBike::ActivatePromotedAlertJob.jobs.count).to eq 1
      end
      context "not activateable" do
        let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver) }
        it "does not activate" do
          Sidekiq::Job.clear_all
          expect(stolen_record.reload.approved?).to be_falsey
          expect do
            post "/admin/promoted_alerts",
              params: {
                promoted_alert: {
                  stolen_record_id: stolen_record.id,
                  promoted_alert_plan_id: promoted_alert_plan.id,
                  notes: "Some notes",
                  ad_radius_miles: 33
                }
              }
          end.to change(PromotedAlert, :count).by 1

          expect(flash[:success]).to be_present
          promoted_alert = PromotedAlert.last
          expect(promoted_alert.admin).to be_truthy
          expect(promoted_alert.user_id).to eq current_user.id
          expect(promoted_alert.stolen_record_id).to eq stolen_record.id
          expect(promoted_alert.bike_id).to eq bike.id
          expect(promoted_alert.ad_radius_miles).to eq 33
          expect(promoted_alert.notes).to eq "Some notes"
          expect(promoted_alert.status).to eq "pending"
          expect(promoted_alert.activateable?).to be_falsey
          expect(promoted_alert.activating?).to be_falsey
          expect(StolenBike::ActivatePromotedAlertJob.jobs.count).to eq 0
        end
      end
    end
  end

  context "given a logged-in non-superuser" do
    before { log_in }
    it { expect(get("/admin/promoted_alerts")).to eq(302) }
    it { expect(get("/admin/promoted_alerts/0/edit")).to eq(302) }
    it { expect(patch("/admin/promoted_alerts/0")).to eq(302) }
  end

  context "given a unauthenticated user" do
    it { expect(get("/admin/promoted_alerts")).to eq(302) }
    it { expect(get("/admin/promoted_alerts/0/edit")).to eq(302) }
    it { expect(patch("/admin/promoted_alerts/0")).to eq(302) }
  end
end
