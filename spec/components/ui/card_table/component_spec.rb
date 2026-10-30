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

  context "with column settings" do
    let(:options) { {records:, column_settings: {storage_key: "testColumns", columns: {email_cell: "Email"}, defaults: %i[email_cell]}} }

    it "renders a card with the column settings, and no form" do
      expect(component).to have_css("div[data-controller~='ui--table-column-settings'] td.email_cell", text: "alice@example.com")
      expect(component).to have_css("[data-controller='ui--table-overflow']")
      expect(component).to have_no_css("form")
      expect(component).to have_no_css("[data-controller~='table-multi-checkbox']")
    end

    context "and a form" do
      let(:options) { super().merge(form: {url: "/bulk", method: :post}, data: {controller: "extra", action: "submit->extra#check", "extra-value": "1"}) }
      let(:component) do
        render_inline(described_class.new(**options)) do |table|
          table.with_actions { "Approve selected" }
          table.column(label: table.toggle_all_button) { "checkbox" }
          table.column(label: "Email", classes: "hideableColumn email_cell") { |r| r.email }
        end
      end

      it "renders the actions above and below, and joins the form's controllers and actions" do
        form = component.css("form[action='/bulk']").first
        expect(form["data-controller"].split).to include("table-multi-checkbox", "ui--table-column-settings", "extra")
        expect(form["data-action"].split).to include("input->table-multi-checkbox#selectRow", "submit->table-multi-checkbox#confirmDiscard", "submit->extra#check")
        expect(form["data-extra-value"]).to eq "1"
        expect(component).to have_css("[data-controller='ui--table-overflow']")
        expect(component.text.scan("Approve selected").size).to eq 2
        expect(component).to have_button(title: "Toggle all checked")
      end
    end
  end
end
