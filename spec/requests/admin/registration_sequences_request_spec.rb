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
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user

    it "blocks non-superusers" do
      get base_url
      expect(response).to_not render_template(:index)
    end
  end
end
