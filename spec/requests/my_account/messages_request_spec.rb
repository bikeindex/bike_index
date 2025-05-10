require "rails_helper"

RSpec.describe MyAccount::MessagesController, type: :request do
  base_url = "/my_account/messages"

  describe "index" do
    context "user not logged in" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(/users\/new/) # weird subdomain issue matching url directly otherwise
      end
    end

    context "user logged in" do
      include_context :request_spec_logged_in_as_user

      context "unconfirmed" do
        let(:current_user) { FactoryBot.create(:user) }
        it "redirects" do
          expect(current_user.confirmed?).to be_falsey
          get base_url
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)
        end
      end

      context "confirmed" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "renders, includes special header tags" do
          expect(current_user.confirmed?).to be_truthy
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
    end
  end
end
