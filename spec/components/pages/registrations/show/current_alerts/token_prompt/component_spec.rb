# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::TokenPrompt::Component, type: :component do
  let(:component) { described_class.new(bike:, current_user:, current_alerts:, variant:) }
  let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
  let(:current_user) { nil }
  let(:variant) { :modal }
  let(:current_alerts) { {} }

  context "a recovery token" do
    let(:current_alerts) { {recovered_stolen_record: bike.current_stolen_record} }

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
      {claim_message: "new_registration", recovered_stolen_record: bike.current_stolen_record}
    end

    # Stacked dialogs would bury each other, so only the highest-precedence opens
    it "renders only the recovery prompt" do
      render_inline(component)
      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to_not have_text("registered your bike on Bike Index")
      expect(page).to have_css("dialog", count: 1)
    end
  end

  # The alert is the same prompt without the dialog, for once the dialog is dismissed
  context "the alert variant" do
    let(:variant) { :alert }
    let(:current_alerts) { {recovered_stolen_record: bike.current_stolen_record} }

    it "renders the prompt whole, with no dialog" do
      render_inline(component)

      expect(page).to have_text("Mark your bike recovered!")
      expect(page).to have_text("Please tell us how you got your bike back")
      expect(page).to have_css("form[action='/bikes/#{bike.id}/recovery']")
      expect(page).to have_button("Mark recovered")

      expect(page).to have_no_css("dialog")
      expect(page).to have_no_button("Nevermind")
    end

    it "gives its form fields their own ids, so the dialog's copy stays unique" do
      render_inline(component)

      expect(page).to have_css("#alert_stolen_record_recovered_description")
      expect(page).to have_no_css("#stolen_record_recovered_description")
    end
  end
end
