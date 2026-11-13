require "rails_helper"

RSpec.describe MyAccounts::PosRegistrationMatchesController, type: :request do
  let(:base_url) { "/my_account/pos_registration_matches" }

  context "signed in as the owner" do
    include_context :request_spec_logged_in_as_user
    let(:pos_registration_match) { FactoryBot.create(:pos_registration_match, user: current_user) }
    let(:url) { "#{base_url}/#{pos_registration_match.id}" }

    it "shows both registrations" do
      get url
      expect(response.status).to eq 200
      expect(response.body).to include("Is this the same bike?", bike_path(pos_registration_match.pos_bike),
        bike_path(pos_registration_match.bike), "name=\"same_bike\"")
    end

    it "combines them, and sends the deleted registration's links to the POS registration" do
      patch url, params: {same_bike: "true"}
      BikeJobs::MergePosRegistrationJob.drain
      pos_bike = pos_registration_match.pos_bike
      expect(response).to redirect_to(bike_path(pos_bike))
      expect(flash[:success]).to eq "Thanks! We're combining your bike's registrations into one. It takes a minute."
      expect(pos_registration_match.reload.status).to eq "merged"
      expect(Bike.unscoped.find(pos_registration_match.bike_id).deleted_at).to be_present

      get url
      expect(response).to redirect_to(bike_path(pos_bike))
      expect(flash[:notice]).to eq "These are already combined into one registration."

      get bike_path(pos_registration_match.bike_id)
      expect(response).to redirect_to(registration_path(pos_registration_match.bike_id))
      get registration_path(pos_registration_match.bike_id)
      expect(response).to redirect_to(registration_path(pos_bike.id))
    end

    it "says it's combining until the merge runs" do
      patch url, params: {same_bike: "true"}
      expect(pos_registration_match.reload.status).to eq "confirmed"
      expect(BikeJobs::MergePosRegistrationJob.jobs.count).to eq 1

      get url
      expect(response).to redirect_to(bike_path(pos_registration_match.pos_bike))
      expect(flash[:notice]).to eq "We're combining these into one registration. It takes a minute."
    end

    it "keeps them separate" do
      patch url, params: {same_bike: "false"}
      expect(response).to redirect_to(my_account_path)
      expect(flash[:success]).to eq "Thanks, we'll keep them as separate registrations."
      expect(pos_registration_match.reload.status).to eq "declined"

      get url
      expect(response).to redirect_to(my_account_path)
      expect(flash[:notice]).to match(/told us these are different/)
    end

    context "stolen since the match" do
      before { FactoryBot.create(:stolen_bike, serial_number: pos_registration_match.bike.serial_number) }

      it "leaves it confirmed and points to support" do
        patch url, params: {same_bike: "true"}
        expect(response).to redirect_to(my_account_path)
        expect(flash[:notice]).to include("couldn't combine")
        expect(pos_registration_match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])
      end
    end

    context "a review candidate" do
      before { pos_registration_match.update!(review_reasons: ["impounded"]) }

      it "doesn't ask" do
        get url
        expect(response).to redirect_to(my_account_path)
        expect(flash[:notice]).to include("can't be combined here")
      end
    end
  end

  context "signed in as someone else" do
    include_context :request_spec_logged_in_as_user
    let(:pos_registration_match) { FactoryBot.create(:pos_registration_match) }

    it "404s" do
      get "#{base_url}/#{pos_registration_match.id}"
      expect(response.status).to eq 404
      patch "#{base_url}/#{pos_registration_match.id}", params: {same_bike: "false"}
      expect(response.status).to eq 404
      expect(pos_registration_match.reload.status).to eq "pending"
    end
  end

  it "sends someone signed out to sign in" do
    get "#{base_url}/#{FactoryBot.create(:pos_registration_match).id}"
    expect(response).to redirect_to(/session/)
  end
end
