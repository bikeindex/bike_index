require "rails_helper"

RSpec.describe Organized::ManageImpoundingsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/manage_impounding" }

  context "given an authenticated ambassador" do
    include_context :request_spec_logged_in_as_ambassador

    let(:org_root_path) { organization_root_path(organization_id: current_organization) }
    it "redirects to the organization root" do
      expect(get(base_url)).to redirect_to(org_root_path)
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user
    describe "index" do
      it "redirects to the organization root path" do
        get base_url
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    let(:impound_configuration) { FactoryBot.create(:impound_configuration) }
    let(:current_organization) { impound_configuration.organization }

    describe "show" do
      it "renders, sets active organization" do
        expect(current_organization.enabled?("impound_bikes")).to be_truthy
        get base_url
        expect(response).to redirect_to(edit_organization_manage_impounding_path(organization_id: current_organization.to_param))
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:passive_organization)).to eq current_organization
      end
    end

    describe "edit" do
      it "renders" do
        get "#{base_url}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template :edit
        expect(assigns(:current_organization)).to eq current_organization
      end
      context "organization doesn't have access" do
        let(:current_organization) { FactoryBot.create(:organization) }
        it "redirects and flash errors" do
          expect(current_organization.reload.enabled?("impound_bikes")).to be_falsey
          get "#{base_url}/edit"
          expect(flash[:error]).to be_present
          expect(response).to redirect_to organization_root_path(organization_id: current_organization.to_param)
        end
      end
    end

    describe "update" do
      let(:update) do
        {
          display_id_prefix: "xXx3",
          public_view: true,
          display_id_next_integer: 324,
          email: "impounding@organization.com",
          expiration_period_days: 333
        }
      end
      it "updates" do
        patch base_url, params: {
          organization_id: current_organization.to_param,
          id: current_organization.to_param,
          impound_configuration: update
        }
        expect(response).to redirect_to edit_organization_manage_impounding_path(organization_id: current_organization.to_param)
        expect(flash[:success]).to be_present
        expect(impound_configuration.reload).to have_attributes update.except(:display_id_next_integer)
        # TODO: this should be updateable for organizations in the future. But skipping for now,
        # to be able to enable, we need to add validations that check that the display_id_next_integer
        expect(impound_configuration.display_id_next_integer).to eq nil
        expect(impound_configuration.expiration_period_days).to eq 333
      end
      context "other update" do
        let(:impound_configuration) { FactoryBot.create(:impound_configuration, public_view: true, email: "something@stuff.com", expiration_period_days: 12) }
        let(:update) { {public_view: "0", display_id_prefix: "1", email: " ", impound_configuration: nil, expiration_period_days: 0} }
        it "updates" do
          patch base_url, params: {
            organization_id: current_organization.to_param,
            id: current_organization.to_param,
            impound_configuration: update
          }
          expect(response).to redirect_to edit_organization_manage_impounding_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
          impound_configuration.reload
          expect(impound_configuration.display_id_prefix).to eq "1"
          expect(impound_configuration.public_view).to be_falsey
          expect(impound_configuration.email).to eq nil
          expect(impound_configuration.expiration_period_days).to eq nil
        end
      end
    end
  end
end
