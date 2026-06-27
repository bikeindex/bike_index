require "rails_helper"

RSpec.describe Organized::RegistrationSequencePagesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequences/#{draft.id}/pages" }
  let(:sequence_path) { organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id) }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

    describe "create" do
      it "adds a blank page and opens it for editing" do
        expect { post base_url }.to change { draft.registration_sequence_pages.count }.by(1)
        page = draft.registration_sequence_pages.reorder(:id).last
        expect(response).to redirect_to("#{base_url}/#{page.id}/edit")
      end
    end

    describe "edit" do
      let(:page) { draft.registration_sequence_pages.first }

      it "renders" do
        get "#{base_url}/#{page.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      let(:page) { draft.registration_sequence_pages.first }

      it "updates the page title, subtitle and bullet points, and redirects to the sequence" do
        patch "#{base_url}/#{page.id}", params: {
          registration_sequence_page: {title: "Battery & charging", subtitle: "Charge safely", bullet_points: ["", "<p>first</p>", "<p>second</p>"]}
        }
        expect(response).to redirect_to(sequence_path)
        expect(page.reload.title).to eq("Battery & charging")
        expect(page.subtitle).to eq("Charge safely")
        expect(page.bullet_points).to eq(["<p>first</p>", "<p>second</p>"])
      end
    end

    describe "destroy" do
      let!(:page) { draft.registration_sequence_pages.first }

      it "removes the page" do
        expect { delete "#{base_url}/#{page.id}" }.to change { draft.registration_sequence_pages.count }.by(-1)
        expect(response).to redirect_to(sequence_path)
      end
    end

    describe "sort" do
      it "reorders the pages to match page_ids" do
        ids = draft.registration_sequence_pages.pluck(:id)
        patch "#{base_url}/sort", params: {page_ids: ids.reverse}
        expect(response.status).to eq(200)
        expect(draft.registration_sequence_pages.reload.pluck(:id)).to eq(ids.reverse)
      end
    end

    context "non-draft sequence" do
      let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

      it "404s on create" do
        post "/o/#{current_organization.to_param}/registration_sequences/#{active.id}/pages"
        expect(response.status).to eq(404)
      end
    end
  end

  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

    it "blocks non-admins" do
      post base_url
      expect(response).to redirect_to(organization_root_path)
    end
  end
end
