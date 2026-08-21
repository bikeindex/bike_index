# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Tabs::Component, type: :component do
  let(:tabs) do
    [{label: "Show", href: "/things/1", active: true},
      {label: "Duplicates", href: "/things/1/duplicates", count: 3}]
  end
  let(:component) { render_inline(described_class.new(tabs:, nav_label: "Thing sections")) }

  it "marks only the active tab, counts only a tab that has one, and leaves turbo alone" do
    # "page" rather than the tab's own boolean - aria-current="false" counts as current
    expect(component.css("a[aria-current]").map { |tab| tab.text.squish }).to eq ["Show"]
    expect(component.css("a").last.text.squish).to eq "Duplicates 3"
    expect(component.css("a").first.css("small")).to be_empty
    # Turbo Drive is off app-wide and opted into per element, so a shared component that
    # switched it on by default would turn it on wherever it was dropped
    expect(component.css("a[data-turbo]")).to be_empty
  end

  it "opts its tabs into turbo when asked" do
    turbo = render_inline(described_class.new(tabs:, nav_label: "Thing sections", turbo: true))

    expect(turbo.css("a[data-turbo='true']").length).to eq tabs.length
  end
end
