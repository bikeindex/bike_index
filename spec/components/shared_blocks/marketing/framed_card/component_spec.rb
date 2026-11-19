# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::FramedCard::Component, type: :component do
  let(:options) do
    {href: "/bikebook", frame: "/bikebook?vehicle_models=x", frame_class: "tw:[--frame-scale:0.4]", icon: "icons/book-open.svg",
     circle: "tw:bg-purple-500", title: "Bike Book", body: "The bicycle library", action: "Browse Bike Book", eyebrow:}
  end
  let(:eyebrow) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "frames the page inert, and links the card to it" do
    expect(component).to have_css("iframe[inert][aria-hidden='true'][tabindex='-1'][loading='lazy'][src='/bikebook?vehicle_models=x'][title='Bike Book']")
    expect(component).to have_css("h3", text: "Bike Book")
    expect(component).to have_link("Browse Bike Book", href: "/bikebook")
    expect(component).to have_css("p", count: 1)
  end

  context "with an eyebrow" do
    let(:eyebrow) { "Your bike garage" }

    it "renders it above the title" do
      expect(component).to have_css("p + h3", text: "Bike Book")
      expect(component).to have_css("p", text: "Your bike garage")
    end
  end
end
