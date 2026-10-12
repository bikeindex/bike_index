require "rails_helper"

RSpec.describe Bikes::RecoveredController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes/#{bike.to_param}/recovered" }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }
  let(:stolen_record) { bike.current_stolen_record }

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq 200
      expect(response.body).to match("How did you get it back?")
    end

    context "not stolen" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }

      it "redirects" do
        get "#{base_url}/new"
        expect(response).to redirect_to bike_path(bike)
      end
    end
  end

  describe "create" do
    let(:recovery_params) do
      {how: "Someone saw the alert", story: "A rider recognized it", recovered_at: "2026-10-09",
       index_helped_recovery: "true", can_share_recovery: "1"}
    end

    it "marks it recovered, then shows the ways to support" do
      expect(stolen_record).to be_present
      expect { post base_url, params: {recovery: recovery_params} }.to change(Feedback, :count).by 1
      expect(response).to redirect_to bike_recovered_path(bike)
      expect(bike.reload.status_stolen?).to be_falsey
      expect(stolen_record.reload).to have_attributes(current: false, recovering_user_id: current_user.id,
        recovered_description: "Someone saw the alert: A rider recognized it", index_helped_recovery: true,
        can_share_recovery: true)
      expect(stolen_record.recovered_at.to_date).to eq Date.parse("2026-10-09")
      expect(Feedback.last).to have_attributes(feedback_type: "bike_recovery", user_id: current_user.id)

      follow_redirect!
      expect(response.status).to eq 200
      expect(response.body).to match("Welcome home")
      expect(response.body).to match("Thanks for letting us share your story")
    end

    context "without the story" do
      it "re-renders" do
        post base_url, params: {recovery: recovery_params.merge(story: " ")}
        expect(response.status).to eq 422
        expect(response.body).to match("A sentence or two is plenty")
        expect(bike.reload.status_stolen?).to be_truthy
      end
    end
  end

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
        expect(response.body).to match("Edit bike details")
        # Shares the register page, which is what it asks friends to do
        expect(response.body).to include("sharer.php?u=#{CGI.escape(new_register_url)}")
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
