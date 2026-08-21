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

  it "renders a tab's count beside its label" do
    expect(component.css("a").last.text.squish).to eq "Duplicates 3"
  end

  # Turbo Drive is off app-wide and opted into per element, so a shared component that
  # switched it on by default would turn it on wherever it was dropped. Absent rather than
  # "false": Turbo reads any other value as opt-in
  it "leaves turbo alone unless asked" do
    expect(component.css("[data-turbo]")).to be_empty
  end

  # One attribute on the nav, which Turbo finds from each link by closest()
  it "opts into turbo on the nav when asked" do
    turbo = render_inline(described_class.new(tabs:, nav_label: "Thing sections", turbo: true))

    expect(turbo.css("nav[data-turbo='true']").length).to eq 1
  end

  it "renders no count when a tab has none" do
    expect(component.css("a").first.css("small")).to be_empty
  end
end
