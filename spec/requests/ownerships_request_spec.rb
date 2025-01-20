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
  end
end
