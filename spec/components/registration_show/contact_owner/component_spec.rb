# frozen_string_literal: true

require "rails_helper"

RSpec.describe RegistrationShow::ContactOwner::Component, type: :component do
  let(:current_user) { nil }

  context "with a non-stolen bike" do
    let(:bike) { FactoryBot.create(:bike) }

    it "does not render" do
      render_inline(described_class.new(bike:, current_user:))

      expect(page).not_to have_text("Contact the owner")
    end
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    context "signed out" do
      let(:current_user) { nil }

      it "renders the card with a sign-in link that returns to this page" do
        render_inline(described_class.new(bike:, current_user:))

        expect(page).to have_text("Contact the owner")
        expect(page).to have_link("Write them a message",
          href: "/session/new?return_to=%2Fregistrations%2F#{bike.id}%3Fcontact_owner%3Dtrue")
        # No in-page message form until the viewer signs in
        expect(page).not_to have_css("textarea[name='stolen_notification[message]']", visible: :all)
      end
    end

    context "signed in" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }

      it "renders the trigger and a hidden message form" do
        render_inline(described_class.new(bike:, current_user:))

        expect(page).to have_text("Contact the owner")
        expect(page).to have_css("[data-registration-show--contact-owner-target='trigger']", text: "Write them a message")
        expect(page).not_to have_link("Write them a message")
        # The form starts collapsed via the tw:hidden class (collapse_utils manages it)
        expect(page).to have_css("[data-registration-show--contact-owner-target='form'].tw\\:hidden")
        expect(page).to have_css("textarea[name='stolen_notification[message]'][required]", visible: :all)
        expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
      end
    end

    context "when the owner's phone is public" do
      before { bike.current_stolen_record.update(phone: "7183914410", phone_for_everyone: true) }

      it "shows the formatted owner phone link" do
        render_inline(described_class.new(bike: bike.reload, current_user:))

        expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
      end
    end
  end
end
