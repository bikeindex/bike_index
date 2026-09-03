# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::JsonDisplay::Component, type: :component do
  let(:component) { render_inline(described_class.new(data:, **options)) }
  let(:data) { {bike: {owner_email: "mothman@bikeindex.org"}} }
  let(:options) { {} }

  it "renders the highlighted json, full width and full size" do
    expect(component.text).to include "owner_email"
    expect(component).to have_css("div.twjson-box pre")
    expect(component).to_not have_css("div.twjson-box[style]")
    expect(component).to_not have_css("div.tw\\:text-xs")
  end

  context "with small and a numeric max_width" do
    let(:options) { {small: true, max_width: 450} }

    it "renders the pixel width and the smaller text" do
      expect(component).to have_css("div.twjson-box.tw\\:text-xs[style='max-width: 450px;']")
    end
  end

  context "with a css max_width" do
    let(:options) { {max_width: "50%"} }

    it "passes the value through" do
      expect(component).to have_css("div[style='max-width: 50%;']")
    end
  end

  context "with blank data" do
    let(:data) { {} }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end
end
