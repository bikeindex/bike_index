require "rails_helper"

RSpec.describe DeveloperRestriction, type: :request do
  # Route constraints check the cookie directly, so we need to set it
  def set_auth_cookie
    cookies[:auth] = Rack::Session::Cookie::Base64::JSON.new.encode({})
  end

  describe "sidekiq" do
    context "not logged in" do
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as regular user" do
      include_context :request_spec_logged_in_as_user
      before { set_auth_cookie }
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as superuser (but not developer)" do
      let(:current_user) { FactoryBot.create(:superuser, developer: false) }
      before do
        log_in(current_user)
        set_auth_cookie
      end
      it "returns 404" do
        get "/sidekiq"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as developer" do
      include_context :request_spec_logged_in_as_developer
      before { set_auth_cookie }
      it "renders" do
        get "/sidekiq"
        expect(response.code).to eq("200")
      end
    end
  end

  describe "pghero" do
    context "not logged in" do
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as regular user" do
      include_context :request_spec_logged_in_as_user
      before { set_auth_cookie }
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as superuser (but not developer)" do
      let(:current_user) { FactoryBot.create(:superuser, developer: false) }
      before do
        log_in(current_user)
        set_auth_cookie
      end
      it "returns 404" do
        get "/pghero"
        expect(response.code).to eq("404")
      end
    end

    context "logged in as developer" do
      include_context :request_spec_logged_in_as_developer
      before { set_auth_cookie }
      it "renders" do
        get "/pghero"
        expect(response.code).to eq("200")
      end
    end
  end
end
