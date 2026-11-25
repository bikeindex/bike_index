# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::RecoveryStories::Index::Component, type: :component do
  include_context :active_stripe_prices
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {recovery_displays:, pagy:, stripe_prices:, current_user:} }
  let(:recovery_displays) { [recovery_display] }
  let(:recovery_display) { FactoryBot.create(:recovery_display, quote: "Police called me") }
  let(:pagy) { Pagy::Offset.new(count: 1, page: 1, limit: 9) }
  let(:current_user) { nil }

  it "renders the stats, the stories and the gift picker" do
    expect(component).to have_css("h1", text: "Every one of these bikes found its way home.")
    expect(component).to have_css("dl dd")
    expect(component).to have_css("turbo-frame#recovery_stories_page_1 blockquote", text: "Police called me")

    expect(component).to have_css("form[action='/membership'] input[name='referral_source'][value='recovery-stories']", visible: :all)
    expect(component).to have_button("Become a member — $15/month")
    expect(component).to have_css("form[action='/payments'] input[name='payment[referral_source]'][value='recovery-stories']", visible: :all)
  end

  context "with a member" do
    let(:current_user) { FactoryBot.create(:user) }
    before { FactoryBot.create(:membership, user: current_user) }

    it "offers only a one-time donation" do
      expect(component).to have_no_css("form[action='/membership']")
      expect(component).to have_button("Donate $50")
    end
  end
end
