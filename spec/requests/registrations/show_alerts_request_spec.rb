# frozen_string_literal: true

require "rails_helper"

# The token-carrying links in Bike Index's emails all point at /bikes/:id, which
# redirects redesign users to /registrations/:id. These walk each link the whole way
# — email link -> redirect -> rendered prompt — because the prompts are the only
# reason those tokens exist, and a redirect that drops one fails silently.
RSpec.describe "RegistrationsController#show alerts", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  before { RearGearType.fixed }

  let(:current_user) { FactoryBot.create(:user_confirmed) }
  # Only the redirect-following examples need the flag; /registrations/:id is direct
  before { Flipper.enable_actor(:bike_show_redesign_toggle, current_user) if current_user.present? }

  describe "recovery link" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user: current_user) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }

    it "carries the session token through the redirect and renders the recovery form once" do
      get "/bikes/#{bike.to_param}/recovery/edit?token=#{recovery_link_token}"
      expect(response).to redirect_to bike_path(bike)
      expect(session[:recovery_link_token]).to eq recovery_link_token

      # bikes#show bounces the redesign user on to the registration
      follow_redirect!
      expect(response).to redirect_to(registration_path(bike))

      follow_redirect!
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Mark your bike recovered!")
      expect(response.body).to match("/bikes/#{bike.id}/recovery")
      expect(response.body).to match(recovery_link_token)

      # Reading it consumes the token, so a reload doesn't re-prompt
      expect(session[:recovery_link_token]).to be_blank
      get "/registrations/#{bike.id}"
      expect(whitespace_normalized_body_text).to_not match("Mark your bike recovered!")
    end

    context "bike is no longer stolen" do
      before { stolen_record.add_recovery_information }

      it "does not prompt for a recovery that already happened" do
        get "/registrations/#{bike.id}"
        expect(whitespace_normalized_body_text).to_not match("Mark your bike recovered!")
      end
    end
  end

  describe "parking notification retrieval link" do
    let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, user: current_user) }
    let!(:notification) { FactoryBot.create(:parking_notification, bike:, organization:, message: "Please move it") }

    it "keeps the token through the redirect and offers to mark it retrieved" do
      get "/bikes/#{bike.id}?parking_notification_retrieved=#{notification.retrieval_link_token}"
      expect(response).to redirect_to(registration_path(bike, parking_notification_retrieved: notification.retrieval_link_token))

      follow_redirect!
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Please move it")
      expect(body).to match("Brakebills sent this notification")
      expect(body).to match("Mark bike retrieved")
      expect(response.body).to match("/bikes/#{bike.id}/resolve_token")
    end

    it "ignores a token that doesn't match" do
      get "/registrations/#{bike.id}?parking_notification_retrieved=nottherightone"
      expect(response.status).to eq(200)
      expect(whitespace_normalized_body_text).to_not match("Mark bike retrieved")
    end
  end

  describe "claim link" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
    let(:ownership) { bike.current_ownership }

    # Signed out, because the claim email's recipient usually has no account yet
    let(:current_user) { nil }

    it "invites them to claim and records the email for signing up" do
      get "/registrations/#{bike.id}?t=#{ownership.token}"
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("registered your bike on Bike Index")
      expect(body).to match("Claim bike")
      expect(session[:claim_token_email]).to eq "new-owner@example.com"
    end

    it "ignores a token that doesn't match" do
      get "/registrations/#{bike.id}?t=nottherightone"
      expect(response.status).to eq(200)
      expect(whitespace_normalized_body_text).to_not match("registered your bike on Bike Index")
      expect(session[:claim_token_email]).to be_blank
    end

    context "signed in as the claimant" do
      let(:current_user) { FactoryBot.create(:user_confirmed, email: "new-owner@example.com") }

      it "offers the one-click claim" do
        get "/registrations/#{bike.id}"
        body = whitespace_normalized_body_text
        expect(body).to match("We're honored to have your bike on the Index")
        expect(response.body).to match("/ownerships/#{ownership.id}")
      end
    end
  end
end
