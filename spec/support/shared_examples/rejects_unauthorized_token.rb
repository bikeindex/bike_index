# frozen_string_literal: true

# API::TokenAuthenticatable's rejection contract. Needs the :admin_doorkeeper_token
# context and a `url`. Answering *no* token stays with the controller - the API
# endpoints 401, the admin pages redirect to sign in.
RSpec.shared_examples "rejects_unauthorized_token" do
  context "a token matching no record" do
    it "returns 401" do
      get url, params: {access_token: "not-a-real-token"}
      expect(response.status).to eq 401
      expect(json_result[:error]).to eq "OAuth token required"
    end
  end

  context "token from the wrong app" do
    before { stub_const("API::TokenAuthenticatable::ADMIN_DOORKEEPER_APP_ID", doorkeeper_app.id + 1) }
    it "returns 403" do
      get url, params: token_param
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Unauthorized application"
    end
  end

  context "token for a non-superuser" do
    it "returns 403" do
      get url, params: token_param
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Not permitted"
    end
  end

  context "token for a user with an unrelated superuser ability" do
    before { FactoryBot.create(:superuser_ability, user: token_user, controller_name: "bikes") }
    it "returns 403" do
      get url, params: token_param
      expect(response.status).to eq 403
      expect(json_result[:error]).to eq "Not permitted"
    end
  end
end
