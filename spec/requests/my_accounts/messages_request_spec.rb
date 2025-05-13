require "rails_helper"

RSpec.describe MyAccounts::MessagesController, type: :request do
  base_url = "/my_account/messages"

  describe "index" do
    context "user not logged in" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(/session\/new/) # weird subdomain issue matching url directly otherwise
        expect(session[:return_to]).to eq "/my_account/messages"
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

        it "renders" do
          expect(current_user.confirmed?).to be_truthy
          # Even though any_for_user is false
          expect(MarketplaceMessage.any_for_user?(current_user)).to be_falsey
          get base_url
          expect(response.status).to eq(200)
          expect(response).to render_template("index")
        end
      end
    end
  end

  describe "show" do
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, status: :for_sale) }
    let(:show_url) { "#{base_url}/show?marketplace_listing_id=#{marketplace_listing.id}" }

    it "redirects" do
      get show_url
      expect(response).to redirect_to(/session\/new/) # weird subdomain issue matching url directly otherwise
      expect(session[:return_to]).to eq show_url
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "renders" do
        expect(marketplace_listing.visible_by?(current_user)).to be_truthy
        get show_url
        expect(response.status).to eq(200)
        expect(response).to render_template("show")
      end

      context "draft item" do
        it "redirects"
      end

      context "sold item" do
        it "renders but doesn't include new marketplace_message"

        context "marketplace_message is a reply" do
          it "renders"
        end
      end

      context "removed" do
        it "renders but doesn't include new marketplace_message"
      end
    end
  end
end
