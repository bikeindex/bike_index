# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe UI::BulkTableCard::Component, type: :component do
  let(:options) { {storage_key: "testColumns", columns: {name_cell: "Name"}, defaults: %i[name_cell]} }
  let(:component) do
    render_inline(described_class.new(**options)) do |card|
      card.with_actions { "Approve selected" } if options[:form]
      card.render(UI::CardTable::Component.new(records: [OpenStruct.new(name: "Alice")])) do |table|
        table.column(label: card.toggle_all_button) { "checkbox" }
        table.column(label: "Name", classes: "hideableColumn name_cell") { it.name }
      end
    end
  end

  it "renders the table and its column settings, with no form" do
    expect(component).to have_css("div[data-controller~='ui--table-column-settings'] td.name_cell", text: "Alice")
    expect(component).to have_no_css("form")
    expect(component).to have_no_css("[data-controller~='table-multi-checkbox']")
  end

  context "with a form" do
    let(:options) { super().merge(form: {url: "/bulk", method: :post}, data: {controller: "extra", action: "submit->extra#check", "extra-value": "1"}) }

    it "renders the actions above and below, and joins the form's controllers and actions" do
      form = component.css("form[action='/bulk']").first
      expect(form["data-controller"].split).to include("table-multi-checkbox", "ui--table-column-settings", "extra")
      expect(form["data-action"].split).to include("input->table-multi-checkbox#selectRow", "submit->table-multi-checkbox#confirmDiscard", "submit->extra#check")
      expect(form["data-extra-value"]).to eq "1"
      expect(component.text.scan("Approve selected").size).to eq 2
      expect(component).to have_button(title: "Toggle all checked")
    end
  end
end
