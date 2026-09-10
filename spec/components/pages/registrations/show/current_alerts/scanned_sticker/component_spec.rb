# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::ScannedSticker::Component, type: :component do
  let(:component) { described_class.new(bike:, bike_sticker:, current_user:) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike:, user: bike.owner) }
  let(:current_user) { bike.owner }

  context "viewer who can't update the sticker" do
    let(:current_user) { nil }

    it "shows the scanned sticker without the re-link form" do
      render_inline(component)
      expect(page).to have_text("You scanned")
      expect(page).to have_text(bike_sticker.pretty_code)
      expect(page).to_not have_button("Change the bike it links to")
    end
  end

  context "viewer authorized for the sticker" do
    it "includes the form to re-link the sticker" do
      render_inline(component)
      expect(page).to have_button("Change the bike it links to")
      # The chevron target is what ui--collapse rotates when the form opens
      expect(page).to have_css("button[data-ui--collapse-target='trigger'] [data-ui--collapse-target='chevron'] svg")
      expect(page).to have_css("form[action='/bike_stickers/#{bike_sticker.code}'] input[name='bike_id']", visible: :all)
      expect(page).to have_button("Update")
    end
  end

  context "no sticker" do
    let(:bike_sticker) { nil }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
