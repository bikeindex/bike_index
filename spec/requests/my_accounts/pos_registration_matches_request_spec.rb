require "rails_helper"

RSpec.describe MyAccounts::PosRegistrationMatchesController, type: :request do
  let(:base_url) { "/my_account/pos_registration_matches" }
  let(:match) { FactoryBot.create(:pos_registration_match, user: current_user) }

  context "signed in as the owner" do
    include_context :request_spec_logged_in_as_user

    it "shows both registrations" do
      get "#{base_url}/#{match.id}"
      expect(response.status).to eq 200
      expect(response.body).to include("Is this the same bike?", bike_path(match.pos_bike), bike_path(match.bike))
    end

    it "combines them" do
      patch "#{base_url}/#{match.id}", params: {same_bike: "true"}
      expect(response).to redirect_to(bike_path(match.pos_bike))
      expect(flash[:success]).to eq "Combined! Your bike is now one registration."
      expect(match.reload.status).to eq "merged"
      expect(Bike.unscoped.find(match.bike_id).deleted_at).to be_present
    end

    it "keeps them separate" do
      patch "#{base_url}/#{match.id}", params: {same_bike: "false"}
      expect(response).to redirect_to(my_account_path)
      expect(match.reload.status).to eq "declined"
      expect(match.bike.reload.deleted_at).to be_blank
    end

    it "leaves a match that can't be merged confirmed for an admin" do
      FactoryBot.create(:stolen_bike, serial_number: match.bike.serial_number)
      patch "#{base_url}/#{match.id}", params: {same_bike: "true"}
      expect(response).to redirect_to(my_account_path)
      expect(flash[:notice]).to include("couldn't combine")
      expect(match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
    end

    it "404s a review candidate" do
      match.update!(review_reasons: ["impounded"])
      get "#{base_url}/#{match.id}"
      expect(response.status).to eq 404
    end
  end

  context "signed in as someone else" do
    include_context :request_spec_logged_in_as_user
    let(:match) { FactoryBot.create(:pos_registration_match) }

    it "404s" do
      get "#{base_url}/#{match.id}"
      expect(response.status).to eq 404
      patch "#{base_url}/#{match.id}", params: {same_bike: "false"}
      expect(response.status).to eq 404
      expect(match.reload.status).to eq "pending"
    end
  end

  it "sends someone signed out to sign in" do
    get "#{base_url}/#{FactoryBot.create(:pos_registration_match).id}"
    expect(response).to redirect_to(/session/)
  end
end
