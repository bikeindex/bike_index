require "rails_helper"

base_url = "/ownerships"
RSpec.describe OwnershipsController, type: :request do
  describe "show" do
    it "sets the flash with absent user for create account" do
      ownership = FactoryBot.create(:ownership)
      get "#{base_url}/#{ownership.id}"
      expect(response).to redirect_to(:new_user)
      expect(flash[:error].match("to claim")).to be_present
      expect(flash[:error].match(/create an account/i)).to be_present
    end

    it "sets the flash with sign in for owner exists" do
      user = FactoryBot.create(:user)
      ownership = FactoryBot.create(:ownership, user: user)
      get "#{base_url}/#{ownership.id}"
      expect(response).to redirect_to(:new_session)
      expect(flash[:error].match("to claim")).to be_present
      expect(flash[:error].match(/sign in/i)).to be_present
    end

    describe "user present" do
      include_context :request_spec_logged_in_as_user
      let(:ownership) { FactoryBot.create(:ownership) }

      it "redirects and not change the ownership" do
        get "#{base_url}/#{ownership.id}"
        expect(response.code).to eq("302")
        expect(flash).to be_present
        expect(ownership.reload.claimed).to be_falsey
      end

      context "ownership isn't current" do
        before { ownership.update(owner_email: current_user.email, current: false) }

        it "redirects and not change the ownership if it isn't current" do
          get "#{base_url}/#{ownership.id}"
          expect(response.code).to eq("302")
          expect(flash[:error]).to be_present
          expect(ownership.reload.claimed).to be_falsey
        end
      end

      context "owner_email upcase" do
        before { ownership.update(owner_email: current_user.email.upcase) }

        it "redirects and mark current based on fuzzy find" do
          get "#{base_url}/#{ownership.id}"
          expect(response.code).to eq("302")
          expect(response).to redirect_to edit_bike_url(ownership.bike)
          expect(flash).to be_present
          expect(ownership.reload.claimed).to be_truthy
        end
      end
    end

    describe "unconfirmed user following claim email link" do
      let(:current_user) { FactoryBot.create(:user) }
      let(:ownership) { FactoryBot.create(:ownership, owner_email: current_user.email) }
      # RearGearType.fixed is required by bike show, otherwise it raises ReadOnlyError
      before do
        RearGearType.fixed
        log_in(current_user)
      end

      it "auto-confirms and claims after visiting the bike page with a valid token" do
        expect(current_user.reload.unconfirmed?).to be_truthy
        get "/bikes/#{ownership.bike.id}", params: {t: ownership.token, email: ownership.owner_email}
        expect(response.code).to eq("200")

        get "#{base_url}/#{ownership.id}"
        expect(response).to redirect_to edit_bike_url(ownership.bike)
        expect(current_user.reload.confirmed?).to be_truthy
        expect(ownership.reload.claimed).to be_truthy
      end

      it "does not confirm when the bike page was not visited with a valid token" do
        get "#{base_url}/#{ownership.id}"
        expect(response).to redirect_to(please_confirm_email_users_path)
        expect(current_user.reload.unconfirmed?).to be_truthy
        expect(ownership.reload.claimed).to be_falsey
      end

      it "does not confirm when the token in the URL does not match" do
        get "/bikes/#{ownership.bike.id}", params: {t: "wrong-token", email: ownership.owner_email}
        expect(response.code).to eq("200")

        get "#{base_url}/#{ownership.id}"
        expect(response).to redirect_to(please_confirm_email_users_path)
        expect(current_user.reload.unconfirmed?).to be_truthy
        expect(ownership.reload.claimed).to be_falsey
      end

      context "current_user email does not match owner_email" do
        let(:ownership) { FactoryBot.create(:ownership, owner_email: "someone-else@example.com") }

        it "does not confirm even if the bike was visited with a valid token" do
          get "/bikes/#{ownership.bike.id}", params: {t: ownership.token, email: ownership.owner_email}
          expect(response.code).to eq("200")

          get "#{base_url}/#{ownership.id}"
          expect(current_user.reload.unconfirmed?).to be_truthy
          expect(ownership.reload.claimed).to be_falsey
        end
      end
    end
  end
end
