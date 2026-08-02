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

  # Claiming writes the ownership, and Ownership touches the bike so this expires
  describe "#cache_key" do
    it "changes when the new owner claims the bike" do
      expect { bike.current_ownership.mark_claimed }.to change { cache_key }
    end

    # The claim-impound card renders the viewer's own claim inside the cached body
    it "changes when the viewer edits their impound claim" do
      impound_record = FactoryBot.create(:impound_record, bike:)
      impound_claim = FactoryBot.create(:impound_claim, impound_record:, user: current_user)
      expect { impound_claim.update(message: "it has my sticker on it") }.to change { cache_key }
    end

    # The alert renders the prompt inside the cached body, token and all, so two
    # notifications on one bike must not share an entry — they're the same component
    it "tells two notifications on the same bike apart" do
      first = FactoryBot.create(:parking_notification, bike:)
      second = FactoryBot.create(:parking_notification, bike:, retrieval_link_token: "another-token")
      keys = [first, second].map do |notification|
        alerts = {token: notification.retrieval_link_token,
                  token_type: notification.kind, matching_notification: notification}
        described_class.new(bike: bike.reload, current_user:, view: [:owner, nil],
          available_views: [], current_alerts: alerts).cache_key
      end

      expect(keys.first).to_not eq keys.last
    end

    # The recovery form's default and max are read off the clock into that same cached
    # alert, so an entry written yesterday must not be served with yesterday's max
    it "carries the recovery prompt's clock-derived bounds" do
      stolen_bike = FactoryBot.create(:stolen_bike, :with_ownership_claimed)
      alerts = {recovered_stolen_record: stolen_bike.current_stolen_record}
      key = described_class.new(bike: stolen_bike, current_user: nil, view: [:public, nil],
        available_views: [], current_alerts: alerts).cache_key

      expect(key.flatten).to include(Binxtils::TimeParser.round(Time.current), Time.current.end_of_day)
    end
  end
end
