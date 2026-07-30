# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::CurrentAlerts::TokenPrompt::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, current_alerts:) }
  let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
  let(:current_user) { nil }
  let(:current_alerts) do
    BikeServices::ShowCurrentAlerts::Resolved.new(claim_message: nil, token: nil, token_type: nil,
      matching_notification: nil, recovered_stolen_record: nil)
  end

  context "a recovery token" do
    let(:current_alerts) { super().with(recovered_stolen_record: bike.current_stolen_record) }

    it "renders the recovery prompt, opened" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to have_css("dialog[data-ui--modal-open-on-connect-value='true']")
    end
  end

  context "no tokens" do
    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "no alerts resolved at all" do
    let(:current_alerts) { nil }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end

  context "when more than one prompt applies" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, owner_email: "new-owner@example.com") }
    let(:current_alerts) do
      super().with(claim_message: "new_registration", recovered_stolen_record: bike.current_stolen_record)
    end

    # Stacked dialogs would bury each other, so only the highest-precedence opens
    it "renders only the recovery prompt" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to_not have_text("registered your bike on Bike Index")
      expect(page).to have_css("dialog", count: 1)
    end
  end
end
