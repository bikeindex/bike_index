# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::WrapperConsumer::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:current_user) { bike.reload.current_ownership.creator }

  # The wrapper folds this into its fragment cache key. Claiming doesn't touch the
  # bike, so without it the sent-to-new-owner alert outlives the claim
  describe "#cache_version" do
    def cache_version
      described_class.new(bike: bike.reload, current_user:, owner: true).cache_version
    end

    it "changes when the new owner claims the bike" do
      expect { bike.current_ownership.mark_claimed }.to change { cache_version }
    end
  end
end
