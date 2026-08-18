# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::Show::StolenDetails::Component, type: :component do
  let(:current_user) { nil }
  let(:bike) { FactoryBot.create(:stolen_bike) }

  context "with a phone only law enforcement can see" do
    before { bike.current_stolen_record.update(phone: "7183914410", phone_for_users: false, phone_for_shops: false) }

    it "does not show the phone to a user without a law enforcement role" do
      render_inline(described_class.new(bike: bike.reload, current_user: FactoryBot.create(:user_confirmed)))

      expect(page).not_to have_css("a[href^='tel:']")
    end

    context "viewed by a law enforcement member" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: FactoryBot.create(:organization, kind: :law_enforcement)) }

      it "shows the formatted owner phone link" do
        render_inline(described_class.new(bike: bike.reload, current_user:))

        expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
      end
    end
  end
end
