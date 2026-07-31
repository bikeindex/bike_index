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

    it "renders the whole prompt, without the dialog that took it away" do
      render_inline(component)

      # The dialog's title, and everything its body holds
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to have_text("Please tell us how you got your bike back")
      expect(page).to have_css("form[action='/bikes/#{bike.id}/recovery']")
      expect(page).to have_css("textarea[name='stolen_record[recovered_description]']")
      expect(page).to have_button("Mark recovered")

      expect(page).to have_no_css("dialog")
      # Dismissing belongs to the dialog; this is what's left once it's dismissed
      expect(page).to have_no_button("Nevermind")
    end

    it "gives its form fields their own ids, so the dialog's copy stays unique" do
      render_inline(component)

      expect(page).to have_css("#alert_stolen_record_recovered_description")
      expect(page).to have_no_css("#stolen_record_recovered_description")
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
    it "renders the same prompt TokenPrompt would open" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to have_no_text("registered your bike on Bike Index")
    end
  end
end
