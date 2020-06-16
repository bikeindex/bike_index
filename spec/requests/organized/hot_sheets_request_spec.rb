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
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_enabled: true) }
        it "renders" do
          get "#{base_url}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template("edit")
        end
      end
    end

    describe "update" do
      it "enables the features we expect" do
        expect(current_organization.hot_sheet_configuration).to be_blank
        Sidekiq::Worker.clear_all
        expect do
          put base_url, params: {
                          hot_sheet_configuration: {
                            is_enabled: true,
                            send_hour: "25",
                            timezone_str: "(GMT-06:00) Central America",
                          },
                        }
        end.to change(HotSheetConfiguration, :count).by 1
        expect(flash[:success]).to be_present
        current_organization.reload
        expect(current_organization.hot_sheet_enabled?).to be_truthy
        expect(current_organization.hot_sheet_configuration).to be_present
        expect(current_organization.hot_sheet_configuration.send_hour).to eq 0

        expect(ProcessHotSheetWorker.jobs.count).to eq 1
        expect(ProcessHotSheetWorker.jobs.map { |j| j["args"] }.flatten).to eq([current_organization.id])
      end
      context "already enabled" do
        let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: current_organization, is_enabled: true) }
        it "updates" do
          Sidekiq::Worker.clear_all
          expect do
            put base_url, params: {
                            hot_sheet_configuration: {
                              is_enabled: false,
                            },
                          }
          end.to_not change(HotSheetConfiguration, :count)
          expect(flash[:success]).to be_present
          current_organization.reload
          expect(current_organization.hot_sheet_configuration).to be_present
          expect(current_organization.hot_sheet_enabled?).to be_falsey

          expect(ProcessHotSheetWorker.jobs.count).to eq 1
          expect(ProcessHotSheetWorker.jobs.map { |j| j["args"] }.flatten).to eq([current_organization.id])
        end
      end
    end
  end
end
