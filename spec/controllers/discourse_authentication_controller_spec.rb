require "spec_helper"

describe DiscourseAuthenticationController do
  describe "index" do
    let(:discourse_query_string) { "sso=bm9uY2U9MGViZDBjMWU2YmZjMDk2MmIxODQ2YzBiYWY4NjNmNDcmcmV0dXJu%0AX3Nzb191cmw9aHR0cCUzQSUyRiUyRmxvY2FsaG9zdCUzQTMwMDAlMkZzZXNz%0AaW9uJTJGc3NvX2xvZ2lu%0A&sig=b1cffd09e878825b0bcdbf2eedf7e7e6133e3ca5acac6854f096bee71786f125" }
    let(:discourse_params) { { "sso" => "bm9uY2U9MGViZDBjMWU2YmZjMDk2MmIxODQ2YzBiYWY4NjNmNDcmcmV0dXJu%0AX3Nzb191cmw9aHR0cCUzQSUyRiUyRmxvY2FsaG9zdCUzQTMwMDAlMkZzZXNz%0AaW9uJTJGc3NvX2xvZ2lu%0A", "sig" => "5b49e8c57feef6f8ca0ae0720388dcf6d46c183be8017413344c388580daaca3" } }

    context "not signed in" do
      it "redirects to sign in and sets discourse_redirect" do
        get :index, discourse_params
        expect(Rack::Utils.parse_query(session[:discourse_redirect])).to eq(discourse_params)
        expect(response).to redirect_to(new_session_path)
      end
    end

    context "signed in as a standard user" do
      include_context :logged_in_as_user

      let(:sso) do
        SingleSignOn.parse(discourse_query_string, ENV["DISCOURSE_SECRET"]).tap do |sso|
          sso.email = user.email
          sso.name = user.name
          sso.external_id = user.id
        end
      end

      it "redirects signed in user from query string" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")

        get :index, Rack::Utils.parse_query(discourse_query_string)

        expect(response).to redirect_to(target_url)
        expect(session[:discourse_redirect]).to be_nil
      end

      it "redirects user from discourse_redirect in session" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
        expect(session[:discourse_redirect]).to be_nil
      end

      it "does not grant admin permissions if the current_user is not a superuser" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
        expect(sso.admin).to be_nil
      end

      it "does not grant moderator permissions if the current_user is not an ambassador" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
        expect(sso.moderator).to be_nil
      end
    end

    context "signed in as a superuser" do
      include_context :logged_in_as_super_admin

      let(:sso) do
        SingleSignOn.parse(discourse_query_string, ENV["DISCOURSE_SECRET"]).tap do |sso|
          sso.email = user.email
          sso.name = user.name
          sso.external_id = user.id
          sso.admin = true
        end
      end

      it "grants admin permissions" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
      end
    end

    context "signed in as an ambassador" do
      include_context :logged_in_as_ambassador

      let(:sso) do
        SingleSignOn.parse(discourse_query_string, ENV["DISCOURSE_SECRET"]).tap do |sso|
          sso.email = user.email
          sso.name = user.name
          sso.external_id = user.id
          sso.moderator = true
        end
      end

      it "grants moderator permissions" do
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
      end
    end

    context "signed in as an ambassador with superuser auth" do
      include_context :logged_in_as_ambassador

      let(:sso) do
        SingleSignOn.parse(discourse_query_string, ENV["DISCOURSE_SECRET"]).tap do |sso|
          sso.email = user.email
          sso.name = user.name
          sso.external_id = user.id
          sso.admin = true
          sso.moderator = true
        end
      end

      it "grants admin and moderator permissions" do
        user.update(superuser: true)
        target_url = sso.to_url("#{ENV["DISCOURSE_URL"]}/session/sso_login")
        session[:discourse_redirect] = discourse_query_string

        get :index

        expect(response).to redirect_to(target_url)
      end
    end
  end
end
