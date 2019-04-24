require "spec_helper"

describe OwnershipsController do
  describe "show" do
    it "sets the flash with absent user for create account" do
      ownership = FactoryBot.create(:ownership)
      put :show, id: ownership.id
      expect(response).to redirect_to(:new_user)
      expect(flash[:error].match("to claim")).to be_present
      expect(flash[:error].match(/create an account/i)).to be_present
    end

    it "sets the flash with sign in for owner exists" do
      user = FactoryBot.create(:user)
      ownership = FactoryBot.create(:ownership, user: user)
      put :show, id: ownership.id
      expect(response).to redirect_to(:new_session)
      expect(flash[:error].match("to claim")).to be_present
      expect(flash[:error].match(/sign in/i)).to be_present
    end

    describe "user present" do
      before :each do
        @user = FactoryBot.create(:user_confirmed)
        @ownership = FactoryBot.create(:ownership)
        set_current_user(@user)
      end

      it "redirects and not change the ownership" do
        put :show, id: @ownership.id
        expect(response.code).to eq("302")
        expect(flash).to be_present
        expect(@ownership.reload.claimed).to be_falsey
      end

      it "redirects and not change the ownership if it isn't current" do
        @ownership.update_attributes(owner_email: @user.email, current: false)
        put :show, id: @ownership.id
        expect(response.code).to eq("302")
        expect(flash).to be_present
        expect(@ownership.reload.claimed).to be_falsey
      end

      it "redirects and mark current based on fuzzy find" do
        @ownership.update_attributes(owner_email: @user.email.upcase)
        put :show, id: @ownership.id
        expect(response.code).to eq("302")
        expect(response).to redirect_to edit_bike_url(@ownership.bike)
        expect(flash).to be_present
        expect(@ownership.reload.claimed).to be_truthy
      end
    end
  end
end
