# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::CurrentAlerts::TokenAlert::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, current_alerts:) }
  let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
  let(:current_user) { nil }
  let(:current_alerts) do
    BikeServices::ShowCurrentAlerts::Resolved.new(claim_message: nil, token: nil, token_type: nil,
      matching_notification: nil, recovered_stolen_record: nil)
  end

  context "a recovery token" do
    let(:current_alerts) { super().with(recovered_stolen_record: bike.current_stolen_record) }

    it "links to the recovery dialog rather than repeating it" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      # ui--modal opens from any [data-open-modal] in the document, so the dialog itself
      # stays outside the fragment cache this alert renders inside
      expect(page).to have_css("button[data-open-modal='recovery-prompt-modal']", text: "Mark recovered")
      expect(page).to_not have_css("dialog")
    end
  end

  context "no tokens" do
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

    # TokenPrompt opens only the highest-precedence dialog, so the alert has to agree
    it "links to the same prompt TokenPrompt would open" do
      render_inline(component)
      expect(page).to have_css("button[data-open-modal='recovery-prompt-modal']")
      expect(page).to_not have_css("button[data-open-modal='claim-invitation-modal']")
    end
  end
end
