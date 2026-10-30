# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::TableColumnSettings::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(columns: {name_cell: "Name", color_cell: "Color"}, defaults: %i[name_cell color_cell], narrow_hidden: %i[color_cell]))
  end

  it "renders a collapsed checkbox per column, marking the defaults and the narrow-hidden" do
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\!")
    expect(component).to have_field("Name", type: "checkbox")
    expect(component).to have_css("input[name='name_cell'][data-default='true'][data-narrow-hidden='false'][data-ui--table-column-settings-target='checkbox']")
    expect(component).to have_css("input[name='color_cell'][data-default='true'][data-narrow-hidden='true']")
    expect(component).to have_button("default")
    expect(component).to have_no_css("[data-ui--table-column-order-target]", visible: :all)
  end

  context "orderable, with sections and copy_order_from" do
    let(:component) do
      render_inline(described_class.new(columns: {name_cell: "Name", color_cell: "Color", size_cell: "Size"}, defaults: %i[name_cell],
        sections: {"Fit columns" => %i[size_cell]}, orderable: true, copy_order_from: {storage_key: "otherThings", label: "Copy other order"}))
    end

    it "lists a section's columns under its heading, after the rest, and returns to the default order or copies the other table's" do
      expect(component.css("h3, input[type='checkbox']").map { it[:name] || it.text.strip }).to eq ["Visible columns", "name_cell", "color_cell", "Fit columns", "size_cell"]
      expect(component).to have_css("[data-ui--table-column-order-target='actions'].tw\\:hidden\\! button[data-ui--table-column-order-target='reset']",
        text: "Return to default column order", visible: :all)
      expect(component).to have_css("button[data-ui--table-column-order-target='copy'][data-storage-key='otherThingsOrder']", text: "Copy other order", visible: :all)
      expect(component).to have_css("[data-ui--table-column-order-target='separator']", visible: :all)
    end
  end

  context "with always_visible and hints" do
    let(:component) do
      render_inline(described_class.new(columns: {view_cell: "View", color_cell: "Color"}, defaults: %i[color_cell],
        always_visible: %i[view_cell], hints: {color_cell: "Frame colors"}))
    end

    it "checks the always-visible column, leaving it out of the controller's reach, and hints after a label" do
      expect(component).to have_field("View", checked: true, disabled: true, visible: :all)
      expect(component.at_css("input[name='view_cell']")["data-ui--table-column-settings-target"]).to be_nil
      expect(component.at_css("label:has(#table_column_settings_color_cell) small").text).to eq "Frame colors"
    end
  end

  context "with field_name" do
    let(:component) do
      render_inline(described_class.new(columns: {"serial" => "Serial", "color" => "Color"}, defaults: %w[serial],
        field_name: "export[headers][]", checked: %w[color]))
    end

    it "renders a form's fields, open, with the controller on the panel and no storage key" do
      expect(component).not_to have_css("[data-ui--collapse-target]")
      expect(component).to have_css("[data-controller='ui--table-column-settings']:not([data-ui--table-column-settings-storage-key-value])")
      expect(component).to have_text("Included columns")
      expect(component).to have_field("export_headers_serial", with: "serial", checked: false)
      expect(component).to have_field("export[headers][]", with: "color", checked: true)
      expect(component.at_css("input[value='serial']")["data-default"]).to eq "true"
      expect(component).to have_no_css("[data-ui--table-column-order-target='reset']", visible: :all)
    end
  end

  describe ".data_attributes" do
    it "runs the collapse and the column settings off the storage key" do
      expect(described_class.data_attributes(storage_key: "adminThings")).to eq(controller: "ui--collapse ui--table-column-settings",
        "ui--collapse-storage-key-value": "adminThingsOpen",
        "ui--table-column-settings-storage-key-value": "adminThings")
    end

    context "orderable, with other controllers" do
      it "adds the column order controller" do
        attributes = described_class.data_attributes(storage_key: "adminThings", controllers: "table-multi-checkbox", orderable: true)
        expect(attributes[:controller]).to eq "table-multi-checkbox ui--collapse ui--table-column-settings ui--table-column-order"
        expect(attributes[:"ui--table-column-order-storage-key-value"]).to eq "adminThingsOrder"
      end
    end
  end
end
