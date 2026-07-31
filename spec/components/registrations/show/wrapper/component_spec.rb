# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::Wrapper::Component, type: :component do
  # The whole show tree renders inside this component's cache block
  it_behaves_like "cached_markup_digest"

  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:current_user) { bike.reload.current_ownership.creator }

  def cache_key
    described_class.new(bike: bike.reload, current_user:, view: [:owner, nil], available_views: []).cache_key
  end

  # Claiming only saves the ownership, so nothing bumps the bike's cache version —
  # without the ownership's timestamp both views would serve stale claim state
  describe "#cache_key" do
    it "changes when the new owner claims the bike" do
      expect { bike.current_ownership.mark_claimed }.to change { cache_key }
    end

    # TokenAlert renders the prompt inside the cached body, token and all, so two
    # notifications on one bike must not share an entry — they're the same component
    it "tells two notifications on the same bike apart" do
      first = FactoryBot.create(:parking_notification, bike:)
      second = FactoryBot.create(:parking_notification, bike:, retrieval_link_token: "another-token")
      keys = [first, second].map do |notification|
        alerts = BikeServices::ShowCurrentAlerts::Resolved.new(claim_message: nil,
          token: notification.retrieval_link_token, token_type: notification.kind,
          matching_notification: notification, recovered_stolen_record: nil)
        described_class.new(bike: bike.reload, current_user:, view: [:owner, nil],
          available_views: [], current_alerts: alerts).cache_key
      end

      expect(keys.first).to_not eq keys.last
    end
  end
end
