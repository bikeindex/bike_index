require "rails_helper"

RSpec.describe Bikes::RecoveredController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes/#{bike.to_param}/recovered" }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }

  describe "show" do
    it "redirects while the bike is still stolen" do
      get base_url
      expect(response).to redirect_to bike_path(bike)
    end

    context "recovered" do
      before { bike.current_stolen_record.add_recovery_information(recovered_description: "Found it", can_share_recovery: true) }

      it "welcomes it home" do
        get base_url
        expect(response.status).to eq 200
        expect(response.body).to match("Welcome home")
        expect(response.body).to match("Thanks for letting us share your story")
      end

      context "someone else's bike" do
        let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }

        it "doesn't show it" do
          get base_url
          expect(response.status).to_not eq 200
        end
      end
    end
  end
end
