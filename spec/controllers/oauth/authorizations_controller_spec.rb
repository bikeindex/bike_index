require "spec_helper"

describe Oauth::AuthorizationsController do
  describe "index" do
    create_v2_access_id
    user = FactoryGirl.create(:user)
    context "no current user present" do
      it "redirects to sign in" do
        get :index
        expect(response).to redirect_to new_session_url
      end
      context "partners" do
        it "redirects to sign in with the partners parameter included" do
          get :index, parter: "bikehub"
          expect(response).to redirect_to new_session_url(parter: "bikehub")
        end
      end
    end
  end
end
