require "rails_helper"

RSpec.describe Organized::RegistrationSequencePagesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/registration_sequences/#{draft.id}/pages" }
  let(:member_url) { "/o/#{current_organization.to_param}/registration_sequence_pages" }
  let(:sequence_path) { edit_organization_registration_sequence_path(organization_id: current_organization.to_param, id: draft.id) }

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    before { current_organization.update_columns(enabled_feature_slugs: %w[registration_sequences registration_sequences_edit]) }
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

    describe "new" do
      it "renders a blank page form without persisting one" do
        expect { get "#{base_url}/new" }.to_not change(RegistrationSequencePage, :count)
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "create" do
      it "adds the page and returns to the sequence" do
        expect {
          post base_url, params: {registration_sequence_page: {title: "Storage", body: "<ul><li>Store safely</li></ul>"}}
        }.to change { draft.registration_sequence_pages.count }.by(1)
        expect(response).to redirect_to(sequence_path)
        expect(draft.registration_sequence_pages.reorder(:id).last.title).to eq("Storage")
      end

      it "re-renders without persisting an incomplete page" do
        expect { post base_url, params: {registration_sequence_page: {title: ""}} }
          .to_not change(RegistrationSequencePage, :count)
        expect(response.status).to eq(422)
        expect(response).to render_template(:edit)
      end
    end

    describe "edit" do
      let(:page) { draft.registration_sequence_pages.first }

      it "renders" do
        get "#{member_url}/#{page.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "update" do
      let(:page) { draft.registration_sequence_pages.first }

      it "updates the page title, subtitle and body, and returns to the page's preview" do
        patch "#{member_url}/#{page.id}", params: {
          registration_sequence_page: {title: "Battery & charging", heading: "Looks like you have an e-vehicle!", subtitle: "Charge safely", body: "<ul><li>first</li><li>second</li></ul>", organization_specific: "1"}
        }
        expect(response).to redirect_to("#{member_url}/#{page.id}/edit")
        expect(page.reload.title).to eq("Battery & charging")
        expect(page.heading).to eq("Looks like you have an e-vehicle!")
        expect(page.subtitle).to eq("Charge safely")
        expect(page.body).to eq("<ul><li>first</li><li>second</li></ul>")
        expect(page.organization_specific).to be_truthy
      end
    end

    describe "destroy" do
      let!(:page) { draft.registration_sequence_pages.first }

      it "removes the page" do
        expect { delete "#{member_url}/#{page.id}" }.to change { draft.registration_sequence_pages.count }.by(-1)
        expect(response).to redirect_to(sequence_path)
      end
    end

    describe "update with a position" do
      it "moves the page to the position and re-sequences" do
        ids = draft.registration_sequence_pages.pluck(:id)
        patch "#{member_url}/#{ids.last}", params: {position: 0}
        expect(response.status).to eq(200)
        expect(draft.registration_sequence_pages.reload.pluck(:id)).to eq([ids.last] + ids[0...-1])
      end
    end

    context "non-draft sequence" do
      let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization: current_organization) }

      it "404s on create" do
        post "/o/#{current_organization.to_param}/registration_sequences/#{active.id}/pages"
        expect(response.status).to eq(404)
      end

      it "404s when editing a page on a non-draft sequence" do
        get "#{member_url}/#{active.registration_sequence_pages.first.id}/edit"
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

  context "logged_in_as_organization_admin without the feature" do
    include_context :request_spec_logged_in_as_organization_admin
    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization: current_organization) }

    it "blocks the org admin" do
      post base_url
      expect(response).to redirect_to(organization_root_path)
      expect(flash[:error]).to be_present
    end

    context "with registration_sequences but not registration_sequences_edit" do
      before { current_organization.update_columns(enabled_feature_slugs: ["registration_sequences"]) }

      it "blocks the org admin" do
        post base_url
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end
  end
end
