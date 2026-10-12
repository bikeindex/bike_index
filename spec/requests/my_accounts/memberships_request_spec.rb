require "rails_helper"

RSpec.describe MyAccounts::MembershipsController, type: :request do
  let(:base_url) { "/my_account/membership" }

  it "redirects to sign in" do
    get base_url
    expect(response).to redirect_to(new_session_path)
  end

  context "logged in" do
    include_context :request_spec_logged_in_as_user

    it "renders" do
      get base_url
      expect(response.code).to eq("200")
      expect(response.body).to match("a Bike Index member")
    end

    context "with a membership" do
      let!(:membership) { FactoryBot.create(:membership_stripe_managed, user: current_user) }

      it "renders" do
        get base_url
        expect(response.code).to eq("200")
        expect(response.body).to match("a Basic member")
        expect(response.body).to match("Manage billing")
      end
    end
  end
end
