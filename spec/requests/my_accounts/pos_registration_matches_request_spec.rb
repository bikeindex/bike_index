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
        bike_path(pos_registration_match.bike), "name=\"answer\"")
    end

    # The emailed link goes through sign in, and Turbo's sign-in form asks for a turbo_stream
    it "shows them as html to a Turbo request" do
      get url, headers: {"Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"}
      expect(response.status).to eq 200
      expect(response.media_type).to eq "text/html"
      expect(response.body).to include("Is this the same bike?")
    end

    it "combines them, and sends the deleted registration's links to the POS registration" do
      patch url, params: {answer: "merge"}
      pos_bike = pos_registration_match.pos_bike
      expect(response).to redirect_to(bike_path(pos_bike))
      expect(flash[:success]).to eq "Thanks! We're combining your bike's registrations into one. It takes a minute."
      expect(pos_registration_match.reload.status).to eq "confirmed"

      # Until the merge runs
      get url
      expect(response).to redirect_to(bike_path(pos_bike))
      expect(flash[:notice]).to eq "We're combining these into one registration. It takes a minute."
      expect(BikeJobs::MergePosRegistrationJob.jobs.count).to eq 1

      BikeJobs::MergePosRegistrationJob.drain
      expect(pos_registration_match.reload.status).to eq "merged"
      expect(Bike.unscoped.find(pos_registration_match.bike_id).deleted_at).to be_present

      get url
      expect(response).to redirect_to(bike_path(pos_bike))
      expect(flash[:notice]).to eq "These are already combined into one registration."

      get bike_path(pos_registration_match.bike_id)
      expect(response).to redirect_to(registration_path(pos_registration_match.bike_id))
      get registration_path(pos_registration_match.bike_id, parking_notification_retrieved: "token")
      expect(response).to redirect_to(registration_path(pos_bike.id, parking_notification_retrieved: "token"))
      get edit_bike_path(pos_registration_match.bike_id, edit_template: "photos")
      expect(response).to redirect_to(edit_bike_path(pos_bike.id, edit_template: "photos"))
      # A form submission isn't sent on
      patch bike_path(pos_registration_match.bike_id), params: {bike: {description: "Lost"}}
      expect(response.status).to eq 404
    end

    context "declining" do
      let(:params) { {answer: "decline"} }

      it "keeps them separate" do
        patch url, params: params
        expect(response).to redirect_to(my_account_path)
        expect(flash[:success]).to eq "Thanks, we'll keep them as separate registrations."
        expect(pos_registration_match.reload.status).to eq "declined"

        get url
        expect(response).to redirect_to(my_account_path)
        expect(flash[:notice]).to match(/told us these are different/)
      end
    end

    context "without an answer" do
      let(:params) { {} }

      it "doesn't record one" do
        patch url, params: params
        expect(response).to redirect_to(url)
        expect(pos_registration_match.reload.status).to eq "pending"
      end
    end

    context "stolen after they said yes" do
      it "points them to support" do
        patch url, params: {answer: "merge"}
        FactoryBot.create(:stolen_bike, serial_number: pos_registration_match.bike.serial_number)
        BikeJobs::MergePosRegistrationJob.drain
        expect(pos_registration_match.reload).to have_attributes(status: "confirmed", review_reasons: ["stolen_history"])

        get url
        expect(response).to redirect_to(my_account_path)
        expect(flash[:notice]).to include("couldn't combine")
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
      patch "#{base_url}/#{pos_registration_match.id}", params: {answer: "decline"}
      expect(response.status).to eq 404
      expect(pos_registration_match.reload.status).to eq "pending"
    end

    # A hidden registration's id isn't revealed by a redirect
    it "404s the deleted registration's links when the POS registration is hidden" do
      pos_registration_match.pos_bike.update!(marked_user_hidden: true)
      pos_registration_match.update!(status: :merged)
      pos_registration_match.bike.destroy!
      get registration_path(pos_registration_match.bike_id)
      expect(response.status).to eq 404
    end
  end

  it "sends someone signed out to sign in" do
    get "#{base_url}/#{FactoryBot.create(:pos_registration_match).id}"
    expect(response).to redirect_to(/session/)
  end
end
