# frozen_string_literal: true

require "rails_helper"

# The token-carrying links in Bike Index's emails point at /bikes/:id, which redirects
# redesign users to /registrations/:id. These walk each link the whole way — email link
# -> redirect -> rendered prompt — because a redirect that drops a token fails silently
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
      # Opened without a click, like the legacy overlay
      expect(response.body).to match("data-ui--modal-open-on-connect-value=\"true\"")

      # Closing the dialog is the end of it, so the body has the prompt whole
      expect(response.body).to match("alert_stolen_record_recovered_description")

      # Reading it consumes the token, so a reload doesn't re-prompt
      expect(session[:recovery_link_token]).to be_blank
      get "/registrations/#{bike.id}"
      body = whitespace_normalized_body_text
      expect(body).to_not match("Mark your bike recovered!")
      expect(response.body).to_not match("alert_stolen_record_recovered_description")
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

    context "already retrieved" do
      # Retrieving keeps the token, so the link in the email still resolves here
      before { notification.mark_retrieved!(retrieved_kind: "organization_recovery", retrieved_by_id: notification.user_id) }

      it "confirms it's resolved instead of offering the form" do
        get "/registrations/#{bike.id}?parking_notification_retrieved=#{notification.retrieval_link_token}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("You have marked this notification resolved")
        expect(body).to match("no further action necessary")
        expect(body).to_not match("Mark bike retrieved")
      end
    end

    context "superseded by a repeat notification" do
      let!(:abandoned) { notification.retrieve_or_repeat_notification!(kind: "appears_abandoned_notification", user: notification.user) }

      # The email links to the original, so that's what has to keep resolving — and its
      # kind is what comes back as token_type
      it "still resolves the notification the link was sent for" do
        ProcessParkingNotificationJob.new.perform(abandoned.id)
        expect(notification.reload.status).to eq "replaced"

        get "/registrations/#{bike.id}?parking_notification_retrieved=#{notification.retrieval_link_token}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("Please move it")
        expect(body).to match("Mark bike retrieved")
        expect(response.body).to match("value=\"parked_incorrectly_notification\"")
      end
    end
  end

  # Graduated rides a different param than parking, so walk this redirect too
  describe "graduated notification link" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features, name: "Brakebills",
        enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year)
    end
    let!(:notification) do
      FactoryBot.create(:graduated_notification_bike_graduated, :with_user, user: current_user, organization:)
    end
    let(:bike) { notification.bike }
    let(:token) { notification.marked_remaining_link_token }

    it "keeps the token through the redirect and offers to mark it remaining" do
      get "/bikes/#{bike.id}?graduated_notification_remaining=#{token}"
      expect(response).to redirect_to(registration_path(bike, graduated_notification_remaining: token))

      follow_redirect!
      expect(response.status).to eq(200)
      body = whitespace_normalized_body_text
      expect(body).to match("Renew your bike registration with Brakebills")
      expect(body).to match("Mark bike remaining")
      expect(response.body).to match("/bikes/#{bike.id}/resolve_token")
      # resolve_token branches on token_type, so the graduated one has to make the round trip
      expect(response.body).to match("value=\"graduated_notification\"")
    end

    it "ignores a token that doesn't match" do
      get "/registrations/#{bike.id}?graduated_notification_remaining=nottherightone"
      expect(response.status).to eq(200)
      expect(whitespace_normalized_body_text).to_not match("Mark bike remaining")
    end

    context "already marked remaining" do
      # Marking remaining keeps the token, so the link in the email still resolves here
      let!(:notification) do
        FactoryBot.create(:graduated_notification, :marked_remaining, :with_user, user: current_user, organization:)
      end

      it "confirms it's resolved instead of offering the form" do
        get "/registrations/#{bike.id}?graduated_notification_remaining=#{token}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to match("You have already marked this bike remaining")
        expect(body).to match("no further action necessary")
        expect(body).to_not match("Mark bike remaining")
      end
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
      expect(body).to match("Sign up")
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

      # The only claim-link case that redirects — the redesign is gated on the signed-in
      # user's flag, so a signed-out recipient stays on the legacy page
      it "keeps the token through the redirect" do
        get "/bikes/#{bike.id}?t=#{ownership.token}"
        expect(response).to redirect_to(registration_path(bike, t: ownership.token))

        follow_redirect!
        expect(response.status).to eq(200)
        expect(whitespace_normalized_body_text).to match("We're honored to have your bike on the Index")
      end

      # Claiming nils the ownership token, so the link goes dead — unlike the notification
      # links, which keep resolving after they've been acted on
      it "stops inviting them once they've claimed it" do
        token = ownership.token
        expect(token).to be_present
        ownership.mark_claimed
        expect(ownership.reload.token).to be_blank

        get "/registrations/#{bike.id}?t=#{token}"
        expect(response.status).to eq(200)
        body = whitespace_normalized_body_text
        expect(body).to_not match("We're honored to have your bike on the Index")
        expect(body).to_not match("registered your bike on Bike Index")
        expect(session[:claim_token_email]).to be_blank
      end
    end
  end
end
