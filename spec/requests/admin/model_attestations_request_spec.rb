require "rails_helper"

base_url = "/admin/model_attestations"
RSpec.describe Admin::ModelAttestationsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      let!(:model_attestation) { FactoryBot.create(:model_attestation) }
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
        expect(assigns(:model_attestations).pluck(:id)).to eq([model_attestation.id])
      end
    end
  end
end
