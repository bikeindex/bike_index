require "rails_helper"

RSpec.describe Organized::RegistrationSequencesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequences" }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    before { current_organization.update_columns(enabled_feature_slugs: ["registration_sequences"]) }

    describe "index" do
      it "renders without creating a draft" do
        expect { get base_url }.to_not change(RegistrationSequence, :count)
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "create" do
      it "builds a draft from the template and redirects to the management page" do
        expect {
          post base_url
        }.to change { current_organization.registration_sequences.draft.count }.by(1)
        draft = current_organization.registration_sequences.draft.first
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id))
      end
    end

    describe "edit" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "renders the draft management view" do
        get "#{base_url}/#{draft.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end

      it "404s for a non-draft sequence" do
        active = FactoryBot.create(:registration_sequence_active, organization: current_organization)
        get "#{base_url}/#{active.id}/edit"
        expect(response.status).to eq(404)
      end
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user

    it "blocks non-admins" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_organization_admin without the feature" do
    include_context :request_spec_logged_in_as_organization_admin

    it "blocks the org admin" do
      get base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:current_organization) { FactoryBot.create(:organization) }

    it "renders even without the feature" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
