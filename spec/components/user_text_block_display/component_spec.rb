# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTextBlockDisplay::Component, type: :component do
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

  context "no text" do
    let(:text) { "\n  " }
    it "does not render" do
      expect(described_class.new(**options).render?).to be_falsey
    end
  end
end
