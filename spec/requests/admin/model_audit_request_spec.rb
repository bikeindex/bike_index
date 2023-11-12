require "rails_helper"

base_url = "/admin/model_audits"
RSpec.describe Admin::ModelAuditsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      let!(:model_audit) { FactoryBot.create(:model_audit) }
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end
  end
end
