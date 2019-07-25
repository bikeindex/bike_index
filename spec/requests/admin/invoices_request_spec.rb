require "rails_helper"

RSpec.describe Admin::InvoicesController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "GET /admin/invoices" do
      it "responds with 200 OK and renders the index template" do
        get "/admin/invoices"
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end
  end
end
