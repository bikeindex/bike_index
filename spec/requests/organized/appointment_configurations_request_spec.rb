require "rails_helper"

RSpec.describe Organized::AppointmentConfigurationsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/appointment_configurations" }

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
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["virtual_line"]) }

    describe "index" do
      it "renders" do
        get base_url
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    let(:current_organization) { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["virtual_line"]) }
    let(:location) { current_organization.locations.first }

    describe "index" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(edit_organization_appointment_configuration_path(location.to_param, organization_id: current_organization.to_param))
      end
      context "no location" do
        let(:current_organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["virtual_line"]) }
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
      context "multiple locations" do
        let!(:location2) { FactoryBot.create(:location_los_angeles, organization: current_organization) }
        it "renders" do
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
    end

    describe "edit" do
      it "renders" do
        get "#{base_url}/#{location.to_param}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template("edit")
      end
      context "with configuration" do
        let!(:appointment_configuration) { FactoryBot.create(:appointment_configuration, organization: current_organization, location: location, virtual_line_on: true) }
        it "renders" do
          get "#{base_url}/#{location.to_param}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template("edit")
        end
      end
    end

    describe "updated" do
      it "turns it on" do
        expect(location.appointment_configuration.present?).to be_falsey
        put "#{base_url}/#{location.to_param}", params: {
                                                  id: location.to_param,
                                                  appointment_configuration: {
                                                    virtual_line_on: "true",
                                                    reasons_text: "something, Something ELSE\n aNOTHER,",
                                                  },
                                                }
        location.reload
        expect(location.appointment_configuration.present?).to be_truthy
        appointment_configuration = location.appointment_configuration
        expect(appointment_configuration.virtual_line_on).to be_truthy
        expect(appointment_configuration.reasons).to match_array(["something", "Something ELSE", "aNOTHER"])
      end
    end
  end
end
