# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/things/1", active: true},
      {label: "Duplicates", href: "/things/1/duplicates", count: 3}]
  end
  let(:component) { render_inline(described_class.new(tabs:, nav_label: "Thing sections")) }

  # aria-current took the tab's own boolean once, so every inactive tab rendered
  # aria-current="false" - which counts as current
  it "marks only the active tab" do
    expect(component.css("a[aria-current]").map { |tab| tab.text.squish }).to eq ["Show"]
  end

  # Below md only the first letter renders, so the rest has to stay announceable
  it "splits the label without losing it, and keeps the count beside it" do
    duplicates = component.css("a").last

    expect(duplicates.text.squish).to eq "Duplicates 3"
    expect(duplicates.at_css("span span").text).to eq "uplicates"
    expect(duplicates.at_css("span span")["class"]).to include "sr-only"
    # no whitespace between the letter and the rest, or the word breaks once both show
    expect(duplicates.at_css("span").inner_html).to start_with "D<span"
  end

  it "renders no count when a tab has none" do
    expect(component.css("a").first.css("small")).to be_empty
  end
end
