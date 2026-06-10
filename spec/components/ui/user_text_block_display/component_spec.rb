# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::UserTextBlockDisplay::Component, type: :component do
  let(:text) do
    "\n\nKnausgaard wolf cornhole, intelligentsia solarpunk cray pour-over gluten-free edison bulb " \
    "fixie squid paleo artisan gochujang gastropub."
  end
  let(:options) { {text:} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(described_class.new(**options).render?).to be_truthy
    expect(component).to be_present
    expect(component).to have_text text.strip
  end

  it "renders without leading whitespace in the text block" do
    inner_html = component.css("div").first.inner_html
    expect(inner_html).to eq(text.strip)
  end

  it "includes the overflow class" do
    expect(component.css("div").first["class"]).to include("tw:overflow-y-auto")
  end

  context "blank max_height_class" do
    let(:options) { {text:, max_height_class: ""} }
    it "omits the overflow class" do
      expect(component.css("div").first["class"]).to_not include("tw:overflow-y-auto")
    end
  end

  context "no text" do
    let(:text) { "\n  " }
    it "does not render" do
      expect(described_class.new(**options).render?).to be_falsey
    end
  end
end
