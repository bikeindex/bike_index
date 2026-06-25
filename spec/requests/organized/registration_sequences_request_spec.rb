require "rails_helper"

RSpec.describe Organized::RegistrationSequencesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequences" }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin

    describe "index" do
      it "renders without creating a draft" do
        expect { get base_url }.to_not change(RegistrationSequence, :count)
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "create" do
      it "builds a draft from the template and redirects to edit" do
        expect {
          post base_url
        }.to change { current_organization.registration_sequences.draft.count }.by(1)
        draft = current_organization.registration_sequences.draft.first
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param, registration_sequence_id: draft.id))
      end
    end

    describe "show" do
      let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

      it "renders the preview" do
        get "#{base_url}/#{active.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
      end
    end

    describe "edit" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

      it "renders" do
        get "#{base_url}/#{draft.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end

      context "non-draft id" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

        it "404s" do
          get "#{base_url}/#{active.id}/edit"
          expect(response.status).to eq(404)
        end
      end
    end

    describe "update" do
      let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }
      let(:page) { draft.registration_sequence_pages.first }

      it "updates the page bullet points without changing status" do
        patch "#{base_url}/#{draft.id}", params: {
          registration_sequence: {registration_sequence_pages_attributes: {"0" => {id: page.id, bullet_points: ["", "<p>first</p>", "<p>second</p>"]}}}
        }
        expect(response).to redirect_to(edit_organization_registration_sequence_path(organization_id: current_organization.to_param, registration_sequence_id: draft.id))
        expect(page.reload.bullet_points).to eq(["<p>first</p>", "<p>second</p>"])
        expect(draft.reload).to be_draft
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
end
