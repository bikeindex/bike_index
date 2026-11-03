# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::Page::Component, type: :component do
  include_context :active_stripe_prices
  let(:options) { {stripe_prices:, recovery_displays: [], initial_amount:} }
  let(:initial_amount) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders the wall and labels the closing CTA with the form's selection" do
    expect(component).to have_css("img[src='#{described_class::WALL_PHOTOS.first}']", count: 1)
    expect(component).to have_button("Become a member — $15/month", count: 2)
    expect(component).to have_no_css("a[data-amount][data-active='true']")
  end

  context "with over a million bikes" do
    before { Counts.assign_for("total_bikes", 1_199_999) }

    it "floors the count to a tenth of a million" do
      expect(component).to have_text("1.1M+")
    end
  end

  context "with a major gift initial_amount" do
    let(:initial_amount) { "1000" }

    it "marks that gift's card" do
      expect(component).to have_css("a[data-amount='1000'][data-active='true']")
      expect(component).to have_css("a[data-amount='500'][data-active='false']")
      expect(component).to have_button("Donate $1,000", count: 2)
    end
  end
end
