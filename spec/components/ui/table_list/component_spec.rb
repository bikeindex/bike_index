# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableList::Component, type: :component do
  let(:options) { {} }
  let(:component) do
    render_inline(described_class.new(**options)) do |list|
      list.with_row(label: "Name", value: "Mothman")
      list.with_row(label: "ID", value: "42", dev_only: true)
      list.with_row(label: "Region", class: "small", data: {kind: "place"}) { "West Virginia" }
    end
  end

  it "renders a row header beside each value" do
    expect(component).to have_css("table.ui-table tbody tr", count: 3)
    expect(component).to have_css("tr:first-child th[scope='row']", text: "Name")
    expect(component).to have_css("tr:first-child td.tw\\:w-\\[85\\%\\]", text: "Mothman")
    expect(component).to have_css("tr.small[data-kind='place']:last-child td", text: "West Virginia")
    expect(component).to have_css("th.only-dev-visible", text: "ID")
    expect(component).to have_css("th.only-dev-visible", count: 1)
    expect(component).not_to have_css("thead")
  end

  context "with wide_definition and classes" do
    let(:options) { {wide_definition: true, classes: "mt-4"} }

    it "narrows the value column" do
      expect(component).to have_css("table.ui-table.mt-4")
      expect(component).to have_css("td.tw\\:w-\\[70\\%\\]", count: 3)
    end
  end

  context "with no rows" do
    it "renders nothing" do
      expect(render_inline(described_class.new).to_html).to eq ""
    end
  end
end
