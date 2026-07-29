# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::CurrentAlerts::Wrapper::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, bike_sticker:, owner: true) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:) }
  let(:current_user) { bike.owner }

  it "renders each alert that applies" do
    render_inline(component)
    expect(page).to have_text("You scanned")
    expect(page).to have_text("You sent this bike to new-owner@example.com")
  end

  context "no sticker, and the owner claimed it" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:bike_sticker) { nil }

    it "renders nothing" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
