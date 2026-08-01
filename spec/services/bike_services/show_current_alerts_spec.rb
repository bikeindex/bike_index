# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::ShowCurrentAlerts do
  let(:alerts) { described_class.find(bike:, params:, recovery_link_token:) }
  let(:params) { ActionController::Parameters.new }
  let(:recovery_link_token) { nil }

  describe "claim token" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
    let(:ownership) { bike.current_ownership }

    context "matching token" do
      let(:params) { ActionController::Parameters.new(t: ownership.token) }

      it "returns the ownership's claim message" do
        expect(alerts[:claim_message]).to eq ownership.claim_message
        expect(alerts[:claim_message]).to be_present
      end
    end

    context "nonmatching token" do
      let(:params) { ActionController::Parameters.new(t: "#{ownership.token}x") }

      it "returns no claim message" do
        expect(alerts[:claim_message]).to be_nil
      end
    end

    context "no token" do
      it "returns no claim message" do
        expect(alerts[:claim_message]).to be_nil
      end
    end

    context "already claimed" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let(:params) { ActionController::Parameters.new(t: ownership.token) }

      it "returns no claim message" do
        expect(alerts[:claim_message]).to be_nil
      end
    end
  end

  describe "parking notification token" do
    let(:bike) { FactoryBot.create(:bike) }
    let!(:notification) { FactoryBot.create(:parking_notification, bike:) }
    let(:params) { ActionController::Parameters.new(parking_notification_retrieved: notification.retrieval_link_token) }

    it "finds the notification and its kind" do
      expect(alerts[:matching_notification]).to eq notification
      expect(alerts[:token_type]).to eq notification.kind
      expect(alerts[:token]).to eq notification.retrieval_link_token
    end

    context "token doesn't match" do
      let(:params) { ActionController::Parameters.new(parking_notification_retrieved: "nope") }

      it "falls back to the default kind with no notification" do
        expect(alerts[:matching_notification]).to be_nil
        expect(alerts[:token_type]).to eq "parked_incorrectly_notification"
      end
    end

    context "notification is for a different bike" do
      let(:other_notification) { FactoryBot.create(:parking_notification) }
      let(:params) { ActionController::Parameters.new(parking_notification_retrieved: other_notification.retrieval_link_token) }

      it "does not find it" do
        expect(alerts[:matching_notification]).to be_nil
      end
    end
  end

  describe "graduated notification token" do
    let(:organization) do
      FactoryBot.create(:organization_with_organization_features,
        enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year)
    end
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let!(:notification) { FactoryBot.create(:graduated_notification, bike:, organization:) }
    let(:params) { ActionController::Parameters.new(graduated_notification_remaining: notification.marked_remaining_link_token) }

    it "finds the notification" do
      expect(alerts[:matching_notification]).to eq notification
      expect(alerts[:token_type]).to eq "graduated_notification"
    end
  end

  describe "recovery link token" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }

    it "finds the stolen record" do
      expect(alerts[:recovered_stolen_record]).to eq stolen_record
    end

    context "nonmatching token" do
      let(:recovery_link_token) { "nope" }

      it "finds nothing" do
        expect(alerts[:recovered_stolen_record]).to be_nil
      end
    end

    context "bike is no longer stolen" do
      # Freshly loaded, like the recovery controller does — reusing the instance that
      # minted the token carries its skip_update flag over, leaving bikes.status stale
      before do
        recovery_link_token
        StolenRecord.unscoped.find(stolen_record.id).add_recovery_information
      end

      it "finds nothing — there's nothing left to recover" do
        expect(bike.reload.status_stolen?).to be_falsey
        expect(alerts[:recovered_stolen_record]).to be_nil
      end
    end
  end
end
