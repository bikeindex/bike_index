require "rails_helper"

RSpec.describe Organized::HotSheetsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/hot_sheet" }

  context "organization not enabled" do
    include_context :request_spec_logged_in_as_organization_member
    let(:current_organization) { FactoryBot.create(:organization) }
    it "redirects" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_organization_member" do
    include_context :request_spec_logged_in_as_organization_member
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }

    describe "show" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
        expect(assigns(:hot_sheet).current?).to be_truthy
        expect(assigns(:current)).to be_truthy
        expect(assigns(:day)).to be_blank
      end
      context "current hot_sheet" do
        let!(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: current_organization) }
        it "renders" do
          get "#{base_url}?day=#{Time.current.to_date}"
          expect(response.status).to eq(200)
          expect(response).to render_template("show")
          expect(assigns(:hot_sheet)).to eq(hot_sheet)
          expect(assigns(:current)).to be_falsey
          expect(assigns(:day)).to eq Time.current.to_date
        end
      end
    end

    describe "edit" do
      it "redirects to the organization root path" do
        get "#{base_url}/edit"
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }

    describe "show" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end
    end

    describe "edit" do
      it "renders" do
        get "#{base_url}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template("edit")
      end
      context "with configuration" do
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_on: true) }
        it "renders" do
          get "#{base_url}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template("edit")
        end
      end
    end

    describe "update" do
      context "enabled after the send_hour" do
        let(:current_hour) { Time.current.in_time_zone("America/Guatemala").seconds_since_midnight / 3600 }
        let(:enabled_params) do
          {
            hot_sheet_configuration: {
              is_on: true,
              send_hour: current_hour.floor.to_s,
              timezone_str: "America/Guatemala",
              search_radius_miles: "1000.1",
            },
          }
        end
        it "creates and enables the features we expect" do
          expect(current_organization.hot_sheet_configuration).to be_blank
          Sidekiq::Worker.clear_all
          expect do
            put base_url, params: enabled_params
          end.to change(HotSheetConfiguration, :count).by 1
          expect(flash[:success]).to be_present
          current_organization.reload
          expect(current_organization.hot_sheet_on?).to be_truthy
          hot_sheet_configuration = current_organization.hot_sheet_configuration
          expect(hot_sheet_configuration.send_hour).to eq current_hour.floor
          expect(hot_sheet_configuration.send_today_now?).to be_truthy
          expect(hot_sheet_configuration.timezone_str).to eq "America/Guatemala"
          expect(hot_sheet_configuration.search_radius_miles).to eq 1000.1

          expect(ProcessHotSheetWorker.jobs.count).to eq 1
          expect(ProcessHotSheetWorker.jobs.map { |j| j["args"] }.flatten).to eq([current_organization.id])
        end
        context "already sent today" do
          let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_on: false, timezone_str: "America/Los_Angeles") }
          let!(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: current_organization, delivery_status: "email_success") }
          it "does not send again" do
            expect(current_organization.hot_sheet_configuration).to eq hot_sheet_configuration
            Sidekiq::Worker.clear_all
            expect do
              put base_url, params: enabled_params
            end.to_not change(HotSheetConfiguration, :count)
            expect(flash[:success]).to be_present
            current_organization.reload
            hot_sheet_configuration.reload
            expect(current_organization.hot_sheet_on?).to be_truthy
            expect(hot_sheet_configuration.send_hour).to eq current_hour.floor
            expect(hot_sheet_configuration.send_today_at).to be < Time.current
            expect(hot_sheet_configuration.send_today_now?).to be_falsey
            expect(hot_sheet_configuration.timezone_str).to eq "America/Guatemala"
            expect(hot_sheet_configuration.search_radius_miles).to eq 1000.1
            # Additional test, because we need to be sure that the timezone str is still parseable
            expect(hot_sheet_configuration.timezone).to eq ActiveSupport::TimeZone["America/Guatemala"]

            expect(ProcessHotSheetWorker.jobs.count).to eq 0
          end
        end
      end
      context "already enabled" do
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_on: true, timezone_str: "America/Los_Angeles") }
        it "turns off if set off" do
          current_organization.update(search_radius: 101)
          Sidekiq::Worker.clear_all
          expect do
            put base_url, params: {
                            hot_sheet_configuration: {
                              is_on: "false",
                              send_hour: 26,
                              timezone_str: "Some weird thing",
                              search_radius_kilometers: 401.5,
                            },
                          }
          end.to_not change(HotSheetConfiguration, :count)
          expect(flash[:success]).to be_present
          current_organization.reload
          hot_sheet_configuration.reload
          expect(current_organization.hot_sheet_on?).to be_falsey
          expect(current_organization.hot_sheet_configuration).to be_present
          # We make the hour 0 if an invalid hour is passed
          expect(hot_sheet_configuration.send_hour).to eq 0
          # We round kms here, for display ease
          expect(hot_sheet_configuration.search_radius_kilometers).to eq 401
          # Because we don't actually store rounded numbers
          expect(hot_sheet_configuration.search_radius_miles).to be_within(0.01).of(646.15)
          expect(hot_sheet_configuration.timezone_str).to be_blank

          expect(ProcessHotSheetWorker.jobs.count).to eq 0
        end
      end
    end
  end
end
