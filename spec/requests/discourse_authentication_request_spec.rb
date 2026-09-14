require "rails_helper"

RSpec.describe DiscourseAuthenticationController, type: :request do
  base_url = "/discourse_authentication"

  let(:discourse_query_string) { "sso=bm9uY2U9MGViZDBjMWU2YmZjMDk2MmIxODQ2YzBiYWY4NjNmNDcmcmV0dXJu%0AX3Nzb191cmw9aHR0cCUzQSUyRiUyRmxvY2FsaG9zdCUzQTMwMDAlMkZzZXNz%0AaW9uJTJGc3NvX2xvZ2lu%0A&sig=b1cffd09e878825b0bcdbf2eedf7e7e6133e3ca5acac6854f096bee71786f125" }
  let(:discourse_params) { {"sso" => "bm9uY2U9MGViZDBjMWU2YmZjMDk2MmIxODQ2YzBiYWY4NjNmNDcmcmV0dXJu%0AX3Nzb191cmw9aHR0cCUzQSUyRiUyRmxvY2FsaG9zdCUzQTMwMDAlMkZzZXNz%0AaW9uJTJGc3NvX2xvZ2lu%0A", "sig" => "5b49e8c57feef6f8ca0ae0720388dcf6d46c183be8017413344c388580daaca3"} }

  let(:sso_attributes) { {} }
  let(:sso) do
    SingleSignOn.parse(discourse_query_string, ENV["DISCOURSE_SECRET"]).tap do |sso|
      sso.email = current_user.email
      sso.name = current_user.name
      sso.external_id = current_user.id
      sso_attributes.each { |key, value| sso.public_send(:"#{key}=", value) }
    end
  end
  let(:target_url) { sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login") }

  describe "index" do
    context "not signed in" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }

      it "stores discourse_redirect, then redirects from it or from the query string once signed in" do
        get "#{base_url}?#{discourse_query_string}"
        expect(response).to redirect_to(new_session_path)
        expect(session[:discourse_redirect]).to eq discourse_query_string

        log_in(current_user)
        get base_url
        # Neither admin nor moderator, so target_url carries neither
        expect(response).to redirect_to(target_url)
        expect(session[:discourse_redirect]).to be_nil

        get base_url, params: Rack::Utils.parse_query(discourse_query_string)
        expect(response).to redirect_to(target_url)
        expect(session[:discourse_redirect]).to be_nil
      end

      it "sets discourse_redirect from params" do
        get base_url, params: discourse_params
        expect(Rack::Utils.parse_query(session[:discourse_redirect])).to eq(discourse_params)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "signed in as a superuser" do
      include_context :request_spec_logged_in_as_superuser
      let(:sso_attributes) { {admin: true} }

      it "grants admin permissions" do
        get base_url, params: Rack::Utils.parse_query(discourse_query_string)
        expect(response).to redirect_to(target_url)
      end
    end

    context "signed in as an ambassador" do
      include_context :request_spec_logged_in_as_ambassador
      let(:sso_attributes) { {moderator: true} }

      it "grants moderator permissions" do
        get base_url, params: Rack::Utils.parse_query(discourse_query_string)
        expect(response).to redirect_to(target_url)
      end

      context "with superuser ability" do
        let(:sso_attributes) { {admin: true, moderator: true} }
        before { FactoryBot.create(:superuser_ability, user: current_user) }

        it "grants admin and moderator permissions" do
          get base_url, params: Rack::Utils.parse_query(discourse_query_string)
          expect(response).to redirect_to(target_url)
        end
      end
    end
  end
end
