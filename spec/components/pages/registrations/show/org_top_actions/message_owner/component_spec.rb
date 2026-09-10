# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::OrgTopActions::MessageOwner::Component, type: :component do
  let(:current_user) { nil }
  let(:bike) { FactoryBot.create(:bike) }

  it "renders the message form" do
    render_inline(described_class.new(bike:, current_user:))

    expect(page).to have_text("Know something about this bike")
    expect(page).to have_css("textarea[name='stolen_notification[message]'][required]", visible: :all)
    expect(page).to have_css("input[name='stolen_notification[bike_id]'][value='#{bike.id}']", visible: :all)
    expect(page).not_to have_text("Or call")
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    before { bike.current_stolen_record.update(phone: "7183914410", phone_for_users: false, phone_for_shops: false) }

    it "does not show the phone to a user without a law enforcement role" do
      render_inline(described_class.new(bike: bike.reload, current_user: FactoryBot.create(:user_confirmed)))

      expect(page).not_to have_text("Or call")
    end

    context "viewed by a law enforcement member" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: FactoryBot.create(:organization, kind: :law_enforcement)) }

      it "shows the formatted owner phone link" do
        render_inline(described_class.new(bike: bike.reload, current_user:))

        expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
      end
    end
  end

  context "with an unstolen bike the owner allows contact about" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "unstolen_notifications") }
    let(:current_user) { FactoryBot.create(:organization_user, organization:) }
    let(:owner) { FactoryBot.create(:user_confirmed, notification_unstolen: true, phone: "7183914410") }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: owner) }

    it "shows the formatted owner phone link" do
      render_inline(described_class.new(bike:, current_user:))

      expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
    end
  end
end
