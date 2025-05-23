require "rails_helper"

RSpec.describe Admin::StripePricesController, type: :request do
  base_url = "/admin/stripe_prices"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end
  end
end
