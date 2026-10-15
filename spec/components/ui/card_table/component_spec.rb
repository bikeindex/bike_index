# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe UI::CardTable::Component, type: :component do
  let(:records) { [OpenStruct.new(name: "Alice", email: "alice@example.com")] }
  let(:options) { {records:} }
  let(:component) do
    render_inline(described_class.new(**options)) do |table|
      table.column(label: "Name") { |r| r.name }
      table.column(label: "Email", classes: "email_cell") { |r| r.email }
    end
  end

  it "renders an unbordered table with the first column frozen" do
    expect(component).to have_css("[data-controller='ui--table-overflow'] table.ui-table:not(.ui-table-bordered)")
    expect(component).to have_css("th.tw\\:sticky", text: "Name")
    expect(component).to have_css("td.tw\\:sticky", text: "Alice")
    expect(component).to have_css("td.email_cell", text: "alice@example.com")
    expect(component).not_to have_css("td.email_cell.tw\\:sticky")
  end

  context "with data" do
    let(:options) { {records:, data: {controller: "org--assign-bike-sticker", foo: "bar"}} }

    it "adds its controllers to the overflow one" do
      expect(component).to have_css("div[data-controller='ui--table-overflow org--assign-bike-sticker'][data-foo='bar']")
    end
  end
end
