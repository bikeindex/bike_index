# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserTextBlockDisplay::Component, type: :component do
  let(:text) do
    "\n\nKnausgaard wolf cornhole, intelligentsia solarpunk cray pour-over gluten-free edison bulb " \
    "fixie squid paleo artisan gochujang gastropub."
  end
  let(:component) { render_inline(described_class.new(text:)) }

  it "renders" do
    expect(component).to be_present
  end
end
