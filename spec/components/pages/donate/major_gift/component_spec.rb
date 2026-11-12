# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Donate::MajorGift::Component, type: :component do
  let(:options) { {amount: 500, href: "/donate?initial_amount=500#donate-form", display: "$500"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "labels the first amount Partner and marks it inactive by default" do
    expect(component).to have_css("a[data-amount='500'][data-active='false']", text: "$500")
    expect(component).to have_text("Partner")
  end

  context "with the second amount, active" do
    let(:options) { super().merge(amount: 1000, display: "$1,000", active: true) }

    it "labels it Benefactor" do
      expect(component).to have_css("a[data-amount='1000'][data-active='true']", text: "$1,000")
      expect(component).to have_text("Benefactor")
    end
  end

  context "small" do
    let(:options) { super().merge(size: :small) }

    it "renders the smaller tile" do
      expect(component).to have_css("a.tw\\:p-4 span.tw\\:text-\\[26px\\]", text: "$500")
    end
  end
end
