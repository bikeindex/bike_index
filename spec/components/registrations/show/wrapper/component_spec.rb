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
  end
end
