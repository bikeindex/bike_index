# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Sticker::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {pretty_code: "BR 000 1"} }

  it "renders the code in a monospace code block" do
    expect(component).to have_css("code", text: "BR 000 1")
    expect(component.to_html).to include("tw:font-mono")
    expect(component).to have_no_css("a")
  end

  context "with a bike_sticker" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "BR1") }
    let(:options) { {bike_sticker:} }

    it "renders the sticker's pretty_code" do
      expect(component).to have_css("code", text: bike_sticker.pretty_code)
    end
  end

  context "with a url" do
    let(:options) { {pretty_code: "BR 000 1", url: "/o/brakebills/stickers/BR1/edit"} }

    it "links the code" do
      expect(component).to have_css("a[href='/o/brakebills/stickers/BR1/edit'] code", text: "BR 000 1")
    end
  end

  context "with a blank code" do
    let(:options) { {bike_sticker: nil} }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
