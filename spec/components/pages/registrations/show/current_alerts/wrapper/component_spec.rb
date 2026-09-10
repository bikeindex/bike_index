# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::Wrapper::Component, type: :component do
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

  # The page wrapper folds this into the fragment key it renders these inside
  describe "#cache_version" do
    let(:component) { described_class.new(bike:, current_user:, bike_sticker: nil, owner: false) }
    let(:bike) { FactoryBot.create(:impound_record).bike.reload }
    let(:current_user) { FactoryBot.create(:user_confirmed) }

    it "carries the viewer's impound claim" do
      expect(component.cache_version).to eq [nil]

      impound_claim = FactoryBot.create(:impound_claim_with_stolen_record, impound_record: bike.current_impound_record,
        user: current_user)

      expect(component.cache_version).to eq [impound_claim.reload.updated_at]
    end

    context "viewed through an organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:component) { described_class.new(bike:, current_user:, organization:) }

      # The claim card doesn't render in the staff panel, so its page shouldn't pay to key on it
      it "asks for nothing" do
        expect(component.cache_version).to eq []
      end
    end
  end
end
