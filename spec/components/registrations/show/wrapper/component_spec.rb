# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::Wrapper::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:current_user) { bike.reload.current_ownership.creator }

  def cache_key
    described_class.new(bike: bike.reload, current_user:, view: [:owner, nil], available_views: []).cache_key
  end

  # Fragment caches don't digest the templates inside them. Rather than a constant
  # someone has to remember to bump, the key carries a digest of the cached markup
  describe "markup digest" do
    let(:template) { Rails.root.join("app/components/registrations/show/current_alerts/wrapper/component.html.erb") }

    it "changes when a cached component's markup changes" do
      original = template.read
      expect { template.write("#{original}\n<!-- edited -->\n") }
        .to change { described_class.markup_digest(described_class::CACHED_MARKUP) }
    ensure
      template.write(original)
    end

    it "ignores previews, which render outside the cache block" do
      preview = Rails.root.join("app/components/registrations/show/org_top_actions/wrapper/component_preview.rb")
      original = preview.read
      expect { preview.write("#{original}\n") }
        .to_not change { described_class.markup_digest(described_class::CACHED_MARKUP) }
    ensure
      preview.write(original)
    end
  end

  # Claiming only saves the ownership, so nothing bumps the bike's cache version —
  # without the ownership's timestamp both views would serve stale claim state
  describe "#cache_key" do
    it "changes when the new owner claims the bike" do
      expect { bike.current_ownership.mark_claimed }.to change { cache_key }
    end
  end
end
