# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::CurrentAlerts::Wrapper::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, bike_sticker:, owner: true, alerts:) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:) }
  let(:current_user) { bike.owner }
  let(:alerts) { nil }

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

  context "with token-scoped alerts" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    let(:bike_sticker) { nil }
    let(:stolen_record) { bike.current_stolen_record }
    let(:alerts) do
      BikeServices::ShowAlerts::Resolved.new(claim_message: nil, token: nil, token_type: nil,
        matching_notification: nil, recovered_stolen_record: stolen_record)
    end

    it "renders the prompt the resolved tokens ask for, opened" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to have_css("dialog[data-ui--modal-open-on-connect-value='true']")
    end
  end

  context "when more than one token prompt applies" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, owner_email: "new-owner@example.com") }
    let(:bike_sticker) { nil }
    let(:alerts) do
      BikeServices::ShowAlerts::Resolved.new(claim_message: "new_registration", token: nil,
        token_type: nil, matching_notification: nil,
        recovered_stolen_record: bike.current_stolen_record)
    end

    # Stacked dialogs would bury each other, so only the first one opens
    it "renders only the highest-precedence one" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to_not have_text("registered your bike on Bike Index")
      expect(page).to have_css("dialog", count: 1)
    end
  end
end
