require "rails_helper"

RSpec.describe Organized::RegistrationSequencesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequence" }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin

    describe "edit" do
      it "renders and builds a draft from the template" do
        expect {
          get "#{base_url}/edit"
        }.to change { current_organization.registration_sequences.draft.count }.by(1)
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }
      let(:page) { draft.pages.first }

      it "updates the page body without changing status" do
        patch base_url, params: {
          registration_sequence: {pages_attributes: {"0" => {id: page.id, body: "## New\n\n- changed"}}}
        }
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param))
        expect(page.reload.body).to eq("## New\n\n- changed")
        expect(draft.reload).to be_draft
      end
    end

    describe "preview" do
      let!(:live) { FactoryBot.create(:registration_sequence_live, :with_pages, organization: current_organization) }

      it "renders the live version" do
        get "#{base_url}/preview", params: {version: "live"}
        expect(response.status).to eq(200)
        expect(response).to render_template(:preview)
      end
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user

    it "blocks non-admins from editing" do
      get "#{base_url}/edit"
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end
  end
end
