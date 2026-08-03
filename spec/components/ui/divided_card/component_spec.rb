# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DividedCard::Component, type: :component do
  it "wraps its content in a bordered, row-divided card" do
    render_inline(described_class.new) { "<p>row one</p><p>row two</p>".html_safe }

    expect(page).to have_css("div[class~='tw:divide-y'][class~='tw:rounded-xl'][class~='tw:border']")
    expect(page).to have_content("row one")
    expect(page).to have_content("row two")
  end
end
