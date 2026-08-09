require "rails_helper"

RSpec.describe Admin::RegistrationSequencesController, type: :request do
  let(:base_url) { "/admin/registration_sequences" }
  let(:organization) { FactoryBot.create(:organization) }

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser

    let!(:draft) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }

    describe "index" do
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:collection).pluck(:id)).to eq([draft.id])
      end

      context "with search_status" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "filters by status" do
          get base_url, params: {search_status: "draft"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([draft.id])
        end
      end
    end

    describe "edit" do
      it "renders the editor for an organization's draft" do
        get "#{base_url}/#{draft.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
        expect(assigns(:registration_sequence)).to eq draft
      end

      context "template" do
        let!(:template) { FactoryBot.create(:registration_sequence_template, :with_pages) }

        it "renders" do
          get "#{base_url}/#{template.id}/edit"
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit)
        end
      end

      context "activated sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "renders, read-only" do
          get "#{base_url}/#{active.id}/edit"
          expect(response.status).to eq(200)
          expect(response.body).to_not include("registration_sequence[faq_url]")
        end
      end
    end

    describe "show" do
      it "renders the sequence read-only" do
        get "#{base_url}/#{draft.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(response.body).to_not include("registration_sequence[faq_url]")
      end
    end

    describe "preview" do
      it "renders the preview walk-through" do
        get "#{base_url}/#{draft.id}/preview", params: {page: 2}
        expect(response.status).to eq(200)
        expect(response).to render_template(:preview)
        expect(assigns(:preview_pagy).page).to eq 2
      end
    end

    describe "update" do
      it "updates the settings shared by every page" do
        patch "#{base_url}/#{draft.id}", params: {
          registration_sequence: {faq_url: "https://example.com/faq", acknowledgment_text: "agree to the rules"}
        }
        expect(response).to redirect_to("#{base_url}/#{draft.id}/edit")
        expect(draft.reload.faq_url).to eq "https://example.com/faq"
        expect(draft.acknowledgment_text).to eq "agree to the rules"
      end

      context "activated sequence" do
        let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }

        it "404s - activation freezes it" do
          patch "#{base_url}/#{active.id}", params: {registration_sequence: {faq_url: "https://example.com/faq"}}
          expect(response.status).to eq(404)
          expect(active.reload.faq_url).to be_blank
        end
      end
    end
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user

    it "blocks non-superusers" do
      get base_url
      expect(response).to_not render_template(:index)
    end
  end
end
