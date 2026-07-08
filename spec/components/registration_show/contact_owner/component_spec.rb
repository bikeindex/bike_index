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

    it "renders the trigger and a hidden message form" do
      render_inline(described_class.new(bike:, current_user:))

      expect(page).to have_text("Contact the owner")
      expect(page).to have_css("[data-registration-show--contact-owner-target='trigger']", text: "Write them a message")
      expect(page).to have_css("[data-registration-show--contact-owner-target='form'][hidden]", visible: :all)
      expect(page).to have_css("textarea[name='stolen_notification[message]'][required]", visible: :all)
      expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
    end

    context "signed out" do
      it "sets the sign-in redirect so the form reopens on return" do
        render_inline(described_class.new(bike:, current_user:))

        redirect = page.find("[data-controller='registration-show--contact-owner']")["data-registration-show--contact-owner-redirect-value"]
        expect(redirect).to eq("/session/new?return_to=%2Fregistrations%2F#{bike.id}%3Fcontact_owner%3Dtrue")
      end
    end

    context "signed in" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }

      it "leaves the redirect blank so the trigger reveals the form in place" do
        render_inline(described_class.new(bike:, current_user:))

        redirect = page.find("[data-controller='registration-show--contact-owner']")["data-registration-show--contact-owner-redirect-value"]
        expect(redirect).to be_blank
      end
    end

    context "when the owner's phone is public" do
      before { bike.current_stolen_record.update(phone: "7183914410", phone_for_everyone: true) }

      it "shows the owner phone link" do
        render_inline(described_class.new(bike: bike.reload, current_user:))

        expect(page).to have_link("7183914410", href: "tel:7183914410")
      end
    end
  end
end
